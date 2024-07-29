//
//  ScreenPickerManager.swift
//  presenterMode
//
//  Created by Ben Jones on 6/13/24.
//

import ScreenCaptureKit
import OSLog
import SwiftUI

//triggered by an update of some sort, but we want to delay firing until the updates stop
//since they'll be coming frequently
struct ConservativeTrigger {
    let framesToWait = 10 // after we hit the trigger, wait this many frames of no-change before firing
    var updateNeededEventually = false
    var framesWithoutChange = 0
    
    //returns if we trigger
    mutating func tick(updateOccurred: Bool) -> Bool {
        if(updateOccurred){
            updateNeededEventually = true
            framesWithoutChange = 0
            return false
        } else {
            if(updateNeededEventually){
                framesWithoutChange += 1
                if(framesWithoutChange >= framesToWait){
                    updateNeededEventually = false
                    return true
                }
            }
        }
        return false
    }
    
    func updateUpcoming() -> Bool {updateNeededEventually}

}

private func rectsApproxEqual(_ r1: CGSize, _ r2: CGSize) -> Bool{
    return (abs(r1.width - r2.width) + abs(r1.height - r2.height)) < 5 //+/- ~ 2 pixels in each dimension seems fine
}

enum FrameType {
    case uncropped(IOSurface)
    case cropped(CGImage)
}

let FrameScaling = 2

private func getStreamConfig(_ streamDimensions: CGSize) -> SCStreamConfiguration {
    let conf = SCStreamConfiguration()
    conf.capturesAudio = false
    conf.width = FrameScaling*Int(streamDimensions.width)
    conf.height = FrameScaling*Int(streamDimensions.height)
    //when false, if the window shrinks, the unused part of the frame is black
    conf.scalesToFit = true
    //60FPS
    conf.minimumFrameInterval = CMTime(value:1, timescale: 60)
    conf.queueDepth = 5 //wait to process up to 5 frames
    Logger().debug("configuration width: \(conf.width) height: \(conf.height)")
    return conf
}

class ScreenPickerManager: NSObject, ObservableObject, SCContentSharingPickerObserver {
    
    private let logger = Logger()
    private let screenPicker = SCContentSharingPicker.shared
    
    
    
    
    private var streamView: StreamView?
    private var scDelegate: SCStreamDelegate?
    private let videoSampleBufferQueue = DispatchQueue(label: "edu.utah.cs.benjones.VideoSampleBufferQueue")
    private var runningStream: SCStream?
    private var app: presenterModeApp?
    private var frameCaptureTask: Task<Void, Never>?
    
    
    @Published var streamAspectRatio = CGSize(width: 1920, height: 1080)
    
    
    func registerView(_ view: StreamView) {
        //TODO: Do we need to clear the old one?
        self.streamView = view
        logger.debug("attaching view to picker manager")
    }
    
    func setApp(app:presenterModeApp){
        self.app = app
    }
    
    
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        logger.debug("Cancelled!!")
    }
    
    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        logger.debug("Updated!")
        logger.debug("Filter rect: \(filter.contentRect.debugDescription) size: \(filter.contentRect.size.debugDescription) scale: \(filter.pointPixelScale) iswindow?: \(filter.style == .window)")
        
        app?.openWindow()
        logger.debug("Stream? : \(stream)")
        guard stream == nil else {
            logger.debug("TODO: Stream is not nil")
            return
        }
        self.frameCaptureTask?.cancel()
        
        self.frameCaptureTask = Task {
            do {
                var frameCount = 0
                let startTime = Date()
                for try await frame in frameSequenceFromFilter(filter: filter) {
                    //logger.debug("Got frame from the stream")
                    
                    //commenting this out doesn't improve things, so this is probably not the bottleneck!!!
                    
                    await self.streamView?.updateFrame(frame)
                    
                    
                    //                    frameCount += 1
                    //                    if(frameCount % 100 == 0){
                    //                        logger.debug("updated \(frameCount) frames")
                    //                        let now = Date()
                    //                        let elapsed = now.timeIntervalSince(startTime)
                    //                        logger.info("for loop running at \(Double(frameCount)/elapsed) FPS")
                    //
                    //                    }
                }
            } catch {
                logger.error("Error with stream: \(error)")
            }
        }
        
        
        
        //        do {
        //            self.runningStream = SCStream(filter: filter, configuration: scConfig, delegate: scDelegate!)
        //            logger.debug("using delegate: \(self.scDelegate)")
        //            try runningStream!.addStreamOutput(scDelegate!, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
        //            runningStream!.startCapture()
        //            logger.debug("capturing should be started: \(self.runningStream)")
        //        } catch {
        //            logger.error("Error setting up stream: \(error)")
        //        }
        
        
    }
    
    func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        logger.debug("Picker start failed failed: \(error)")
    }
    
    func present(){
        if(!screenPicker.isActive){
            screenPicker.isActive = true
            screenPicker.add(self)
        }
        //TODO present for if stream is already running
        screenPicker.present()
    }
    
    func startSharing() async {
        
    }
    
    func frameSequenceFromFilter(filter: SCContentFilter) -> AsyncThrowingStream<FrameType, Error> {
        return AsyncThrowingStream<FrameType, Error> { continuation in
            
            class StreamToFramesDelegate : NSObject, SCStreamDelegate, SCStreamOutput {
                var logger = Logger()
                private var incompleteFrameCount = 0
                private var droppedFrameCount = 0
                private var invalidFrameCount = 0
                private var validFrames = 0
                private var totalFrameCount = 0
                private let startTime = Date()
                
                private var trigger = ConservativeTrigger()
                
                private var streamDimensions = CGSize(width: 1920, height: 1080)
                private var continuation: AsyncThrowingStream<FrameType, Error>.Continuation
                private var screenPickerManager: ScreenPickerManager
                private var filter: SCContentFilter
                
                init(screenPickerManager: ScreenPickerManager, continuation: AsyncThrowingStream<FrameType, Error>.Continuation, filter: SCContentFilter){
                    self.continuation = continuation
                    self.screenPickerManager = screenPickerManager
                    self.filter = filter
                    logger.info("Created stream delegate")
                }
                
                func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of: SCStreamOutputType){
                    //                    self.totalFrameCount += 1
                    //                    if(self.totalFrameCount % 100 == 0){
                    //                        logger.debug("stream FPS: \(Double(self.totalFrameCount)/(Date().timeIntervalSince(self.startTime)))")
                    //                    }
                    guard buffer.isValid else {
                        //                        invalidFrameCount += 1
                        //                        if(invalidFrameCount % 100 == 0){
                        //                            logger.debug("invalid frames so far \(self.invalidFrameCount)")
                        //                        }
                        return
                    }
                    //get the sample buffer attachments for some reason?
                    guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(buffer,
                                                                                         createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                          let attachments = attachmentsArray.first else { return }
                    
                    // Validate the status of the frame. If it isn't `.complete`, return nil.
                    guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
                          let status = SCFrameStatus(rawValue: statusRawValue),
                          status == .complete else {
                        //                        incompleteFrameCount += 1
                        //                        if(incompleteFrameCount % 100 == 0){
                        //                            logger.debug("incomplete frames so far: \(self.incompleteFrameCount)")
                        //                        }
                        return
                    }
                    
                    guard let contentRectDict = attachments[.contentRect],
                          let contentScale = attachments[.contentScale] as? CGFloat,
                          let scaleFactor = attachments[.scaleFactor] as? CGFloat,
                          let contentRect = CGRect(dictionaryRepresentation: contentRectDict as! CFDictionary) else {
                        logger.error("Couldn't get contectRect!")
                        return
                    }
                    let scaledSize = CGSize(width: contentRect.size.width*scaleFactor, height: contentRect.size.height*scaleFactor)
                    let unscaledContentSize = CGSize(width: contentRect.size.width/contentScale, height: contentRect.size.height/contentScale)
                    
                    //logger.debug("got a stream frame!")
                    
                    guard of == SCStreamOutputType.screen else { return }
                    
                    //extract the image
                    guard let pixelBuffer = buffer.imageBuffer else {
                        return
                    }
                    
                    guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
                        logger.error("Couldn't get IOSurface")
                        return
                    }
                   
                    let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)
                    
                    let croppingRequired = !rectsApproxEqual(scaledSize, CGSize(width:surface.width, height: surface.height))
                    //if we don't need to crop then the size couldn't have changed
                    let sizeChanged = croppingRequired && self.streamDimensions != scaledSize
                    if(sizeChanged){
                        //logger.debug("size changed from \(self.streamDimensions.debugDescription) to \(scaledSize.debugDescription) cropping required? \(croppingRequired)")
                        //logger.debug("surface size: \(surface.width) x \(surface.height)")
                        //logger.debug("filter size: \(self.filter.contentRect.size.debugDescription)")
                        self.streamDimensions = scaledSize
                    }
                    
                    let triggered = trigger.tick(updateOccurred: sizeChanged)
                    if(triggered){
                        //update the stream config
                        Task {
                            do {
                                //filter is not updated...
                                logger.debug("updating config with dimensions: \(unscaledContentSize.debugDescription)")
                                try await stream.updateConfiguration(getStreamConfig(unscaledContentSize))
                                logger.debug("stream config updated")
                            } catch {
                                logger.error("couldn't update stream: \(error)")
                            }
                        }
                    }
                    //after the config update happens we should be able to do this
                    if(!croppingRequired){
                        continuation.yield(FrameType.uncropped(surface))
                        return
                    }
                    
                    //crop it to the content rect size
                    let cii = CIImage(ioSurface: surface)
                    let ciContext = CIContext()
                    

                    //the origin for CGImages is the bottom left, not the top left, so we need to update the Y to take that into account
                    
                    //TODO: if the size hasn't changed in a few frames skip all this and just return the IOSurface directly
                    
                    guard let cgImage =
                            ciContext.createCGImage(cii,
                                                    from: CGRect(origin: CGPoint(x: 0, y: surface.height - Int(scaledSize.height)),
                                                                 size: scaledSize)) else {
                        logger.error("Couldn't make CGImage")
                        return
                    }
                    
//                    if(sizeChanged){
//                        Task {
//                            do {
//                                logger.debug("scaled size: \(scaledSize.debugDescription)")
//                                logger.log("Surface size: \(surface.width) x \(surface.height)")
//                                let nowString = Date().timeIntervalSince1970
//                                let url = URL.temporaryDirectory.appending(path:"\(nowString).png", directoryHint: .notDirectory)
//                                
//                                let dest = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil)!
//                                CGImageDestinationAddImage(dest, cgImage, nil)
//                                CGImageDestinationFinalize(dest)
//                                
//                                let urlIoSurf = URL.temporaryDirectory.appending(path:"\(nowString)_iosurf.png", directoryHint: .notDirectory)
//                                try ciContext.writePNGRepresentation(of: cii, to: urlIoSurf, format: CIFormat.ABGR8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
//                                
//                                logger.debug("wrote image to \(url)")
//                                
//                            } catch {
//                                logger.debug("couldn't save file: \(error)")
//                            }
//                        }
//                    }
                    
                    
                    
                    continuation.yield(FrameType.cropped(cgImage))
                    
                }
                
                
                func stream(_ stream: SCStream, didStopWithError error: Error) {
                    logger.debug("STREAM STOPPED WITH ERROR: \(error)")
                    continuation.finish(throwing: error)
                }
            }
            let delegate = StreamToFramesDelegate(screenPickerManager: self, continuation: continuation, filter: filter)
            self.scDelegate = delegate
            self.runningStream = SCStream(filter: filter, configuration: getStreamConfig(filter.contentRect.size), delegate: self.scDelegate!)
            do {
                try self.runningStream?.addStreamOutput(delegate, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
                self.runningStream?.startCapture()
            } catch {
                logger.debug("Start capture failed: \(error)")
            }
        }
    }
    
    
    
    //    init() {
    //        screenPicker.maximumStreamCount = 1
    //
    //        //let config = SCContentSharingPickerConfiguration(allowedPickerModes: .singleWindow, allowsChangingSelectedContent: true)
    //
    //        //screenPicker.setConfiguration(<#T##configuration: SCContentSharingPickerConfiguration?##SCContentSharingPickerConfiguration?#>, for: <#T##SCStream#>)
    //
    //        screenPicker.present()
    //    }
}
