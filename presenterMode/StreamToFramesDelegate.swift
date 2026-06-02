//
//  StreamToFramesDelegate.swift
//  presenterMode
//
//  Created by Ben Jones on 6/13/24.
//

import AVFoundation
import CoreImage
import IOSurface
import OSLog
import ScreenCaptureKit

struct StreamFrameCallbacks {
    let onFrame: (FrameType) -> Void
    let getCurrentFilter: () async -> SCContentFilter?
    let onStreamStop: () -> Void
}

// manage streaming data from SCKit, AV Video devices (camera, ipad), and audio devices
// video frames will get sent to onFrame
// video + audio will get sent to the recorder if we're recording
class StreamToFramesDelegate: NSObject, SCStreamDelegate, SCStreamOutput,
                              AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    var logger = Logger()
    
    private var trigger = ConservativeTrigger()
    private let ciContext = CIContext()
    
    private var streamDimensions = CGSize(width: 1920, height: 1080)
    private var recorder: AVRecorder
    private var callbacks: StreamFrameCallbacks
    
    init(recorder: AVRecorder, callbacks: StreamFrameCallbacks) {
        self.recorder = recorder
        self.callbacks = callbacks
        logger.info("Created stream delegate")
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of: SCStreamOutputType) {
        guard buffer.isValid else {
            logger.info("invalid buffer in stream")
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
            logger.info("incomplete buffer in stream")
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
        
        guard of == SCStreamOutputType.screen else { return }
        
        //extract the image
        guard let pixelBuffer = buffer.imageBuffer else {
            logger.info("couldn't get pixel buffer in stream")
            return
        }
        
        guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            logger.error("Couldn't get IOSurface in stream")
            return
        }
       
        let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)
        
        let croppingRequired = !rectsApproxEqual(scaledSize, CGSize(width:surface.width, height: surface.height))
        //if we don't need to crop then the size couldn't have changed
        let sizeChanged = croppingRequired && self.streamDimensions != scaledSize
        if(sizeChanged){
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
            callbacks.onFrame(FrameType.uncropped(surface))
            if(recorder.recording){
                //TODO mirror frame here, maybe
                recorder.writeFrame(frame: pixelBuffer)
            }
            return
        }
        
        //crop it to the content rect size
        let cii = CIImage(ioSurface: surface)
        //the CVPixelBuffer doesn't support the default format which is RGBA8, so specify that we want it as BGRA8 here
        guard let cgImage =
                ciContext.createCGImage(cii,
                                        from: CGRect(origin: CGPoint(x: 0, y: surface.height - Int(scaledSize.height)),
                                                     size: scaledSize),
                                        format: .BGRA8,
                                        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else {
            logger.error("Couldn't make CGImage")
            return
        }
        callbacks.onFrame(FrameType.cropped(cgImage))
        if(recorder.recording){
            let pb = pixelBufferFromCGImage(image: cgImage)
            if(pb != nil){
                recorder.writeFrame(frame: pb!)
            } else {
                logger.debug("CG to CVPixelBuf conversion failed")
            }
        }
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {

        logger.debug("STREAM STOPPED WITH ERROR")
        let nserr: NSError = error as NSError
        logger.debug("error code \(nserr.code)")
        if(nserr.code == SCStreamError.systemStoppedStream.rawValue){
            logger.debug("System stopped the erorr, restart it!")
            //TODO store the filter and reenable the stream from it
            Task {
                let filter = await callbacks.getCurrentFilter()
                if(filter != nil){
                    do{
                        try await stream.updateContentFilter(filter!)
                    } catch {
                        logger.error("couldn't restart the stream: \(error)")
                    }
                }
            }
            
        } else {
            //continuation.finish()
            callbacks.onFrame(FrameType.cropped(sharingStoppedImage))
            if(recorder.recording){
                recorder.writeFrame(frame: pixelBufferFromCGImage(image: sharingStoppedImage)!)
            }
            callbacks.onStreamStop()
        }
        
        
    }
    
    // like stream methods above, but for AV devices
    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer,
                       from connection: AVCaptureConnection ){
        guard buffer.isValid else {
            logger.debug("invalid AV Buffer")
            return
        }
        
        if(buffer.formatDescription?.mediaType == .video){
            
            guard let pixelBuffer = buffer.imageBuffer else {
                logger.debug("couldn't get AV Pixel buffer")
                return
            }
            
            guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
                logger.error("Couldn't get IOSurface")
                return
            }
            
            let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)
            callbacks.onFrame(FrameType.uncropped(surface))
            if(recorder.recording){
                //TODO mirror frame here, maybe
                recorder.writeFrame(frame: pixelBuffer)
            }
        } else if(buffer.formatDescription?.mediaType == .audio){
            if(recorder.recording){
                recorder.writeAudioSample(buffer:buffer)
            }
        } else {
            logger.debug("unknown format: \(buffer.formatDescription.debugDescription)")
        }
    }
    
    func captureOutput(_: AVCaptureOutput, didDrop: CMSampleBuffer, from: AVCaptureConnection){
        logger.debug("AV frame dropped")
    }
}
