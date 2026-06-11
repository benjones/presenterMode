//
//  ScreenPickerManager.swift
//  presenterMode
//
//  Created by Ben Jones on 6/13/24.
//

import ScreenCaptureKit
import OSLog
import SwiftUI
import CollectionConcurrencyKit
import AVFoundation
import Combine

enum FrameType {
    case uncropped(IOSurface)
    case cropped(CGImage)
}

struct HistoryEntry {
    let scWindow : SCWindow
    var preview: CGImage?
}


let sharingStoppedImage: CGImage = CGImage(
    pngDataProviderSource: CGDataProvider(data: NSDataAsset(name: "sharingStopped")!.data as CFData)!,
    decode: nil, shouldInterpolate: true, intent: .defaultIntent)!


@MainActor
class StreamManager: NSObject, ObservableObject, SCContentSharingPickerObserver {
    
    @Published var history = [HistoryEntry]()
    @Published var recording = false
    
    private let logger = Logger()
    private let screenPicker = SCContentSharingPicker.shared
    
    private let avDeviceManager: AVDeviceManager
    
    
    
    //only used to open a window... seems like a bad design
    private let windowOpener: WindowOpener
    private var streamView: StreamView?
    public var scDelegate: StreamToFramesDelegate?
    public let videoSampleBufferQueue = DispatchQueue(label: "edu.utah.cs.benjones.VideoSampleBufferQueue")
    private var runningStream: SCStream?
    //used for restarting stopped stream
    //also in the future, storing previous filters in the history view
    private var currentFilter: SCContentFilter?
    
    private var frameCaptureTask: Task<Void, Never>?
    
    let avRecorder = AVRecorder()
    @Published var audioLevel: Float = 0
    
    private var audioMeterTask: AnyCancellable?
    
    
    init(avManager: AVDeviceManager, windowOpener: WindowOpener) {
        self.avDeviceManager = avManager
        self.windowOpener = windowOpener
    }
    
    func setupTask(){
        self.frameCaptureTask = Task {
            do {
                for try await frame in getFrameSequence(){
                    self.streamView?.updateFrame(frame)
                    
                }
            } catch {
                logger.error("Error with stream: \(error)")
            }
            logger.debug("Frame Sequence loop ended for some reason")
            //so the stream can restart in the future
            //TODO FIXME!!!
            self.streamView?.updateFrame(FrameType.cropped(sharingStoppedImage))
            self.frameCaptureTask = nil
        }
    }
    
    
    func startRecording(url: URL, audioDevice: AVCaptureDevice?){
        recording = avRecorder.startRecording(url: url, audioDevice: audioDevice, delegate: scDelegate!)
        
        audioMeterTask = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
            self.audioLevel = avRecorder.audioLevels.peakLevel
        }
    }
    
    func stopRecording(){
        if(recording) {
            avRecorder.finishRecording()
            self.audioLevel = 0
            audioMeterTask?.cancel()
            recording = false
            logger.debug("finished recording")
        }
    }
    
    func registerView(_ streamView: StreamView) {
        //TODO: Do we need to clear the old one?
        self.streamView = streamView
        logger.debug("attaching view to picker manager")
    }
    
    //TODO MOVE OUT OF THIS BIG CLASS!
    func streamAVDevice(device: AVCaptureDevice, avMirroring: Bool){
        logger.debug("want to stream device: \(device.localizedName)")
        runningStream?.stopCapture()
        runningStream = nil
        currentFilter = nil

        avDeviceManager.setupCaptureSession(
            device: device,
            delegate: scDelegate,
            sampleBufferQueue: videoSampleBufferQueue
        )
        updateAVMirroring(avMirroring: avMirroring)
    }
    
    func updateAVMirroring(avMirroring: Bool){
        streamView?.setAVMirroring(mirroring: avMirroring)
    }
    
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in
            self.handleContentSharingPickerCancel(stream: stream)
        }
    }
    
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
            self.handleContentSharingPickerUpdate(filter: filter, stream: stream)
        }
    }
    
    private func handleContentSharingPickerCancel(stream: SCStream?) {
        logger.debug("Cancelled!!")
    }
    
    private func handleContentSharingPickerUpdate(filter: SCContentFilter, stream: SCStream?) {
        
        logger.debug("Updated from picker!")
        logger.debug("Filter rect: \(filter.contentRect.debugDescription) size: \(filter.contentRect.size.debugDescription) scale: \(filter.pointPixelScale) iswindow?: \(filter.style == .window)")
        logger.debug("stream: \(stream)")
        
        //don't expect either of these things to ever happen
        if(stream == nil && runningStream != nil){
            logger.debug("CSP stream is nil, but not the running stream! \(self.runningStream)")
        } else if(stream != self.runningStream){
            logger.debug("CSP stream and self.runnign stream are different! cspStream: \(stream) self.stream: \(self.runningStream)")
        }
        setFilterForStream(filter: filter)
    }
    
    func createStream(filter: SCContentFilter){
        self.runningStream = SCStream(filter: filter, configuration: getStreamConfig(filter.contentRect.size), delegate: self.scDelegate!)
        logger.debug("created new stream: \(self.runningStream)")
        if let runningStream {
            configurePicker(for: runningStream)
        }
        do {
            try self.runningStream?.addStreamOutput(scDelegate!, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
            self.runningStream?.startCapture()
        } catch {
            logger.debug("Start capture failed: \(error)")
        }
    }
    
    func setFilterForStream(filter: SCContentFilter) {
        avDeviceManager.stopSharing()
        Task { @MainActor in
            
            await windowOpener.openWindow()
            await updateHistory(filter: filter)
            
        }
        if(runningStream == nil){
            createStream(filter: filter)
        }
        Task {
            do {

                try await self.runningStream?.updateContentFilter(filter)
                try await self.runningStream?.updateConfiguration(getStreamConfig(filter.contentRect.size))

            } catch {
                logger.error("Couldn't update stream on picker change: \(error)")
            }
            currentFilter = filter
        }
        
    }
    
    func updateHistory(filter: SCContentFilter) async {
        switch(filter.style){
        case .window:
            
            //hack to get the window being shared
            let matchingWindows = await getCurrentlySharedWindow(size: filter.contentRect.size)
            
            //TODO, remove any history entries which aren't in matchingwindows anymore
            Task { @MainActor in
                self.history.removeAll{ window in matchingWindows.contains(window.scWindow)}
                await self.history.append(contentsOf: matchingWindows.concurrentCompactMap{ window in
                    let config = SCStreamConfiguration()
                    config.width = Int(window.frame.width)
                    config.height = Int(window.frame.height)
                    config.scalesToFit = true
                    do {
                        let screenshot = try await SCScreenshotManager.captureImage(
                            contentFilter: SCContentFilter(desktopIndependentWindow: window),
                            configuration: config)
                        return HistoryEntry(scWindow: window, preview: screenshot)
                    } catch {
                        self.logger.debug("history entry add failed: \(error)")
                    }
                    return nil
                })
            }
        case .none:
            logger.error("Filter has no style (type)")
            return
        case .display:
            logger.debug("sharing a full display, not adding to history")
        case .application:
            logger.debug("sharing an application, not adding to history")
        @unknown default:
            logger.error("Filter has unknown style (type)")
        }
    }
    
    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in
            self.handleContentSharingPickerStartFailure(error)
        }
    }
    
    private func handleContentSharingPickerStartFailure(_ error: any Error) {
        logger.debug("Picker start failed failed: \(error)")
    }
    
    private func windowPickerConfiguration() -> SCContentSharingPickerConfiguration {
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = .singleWindow
        configuration.allowsChangingSelectedContent = true
        return configuration
    }
    
    private func configurePicker(for stream: SCStream) {
        screenPicker.setConfiguration(windowPickerConfiguration(), for: stream)
    }
    
    func present(){
        if(!screenPicker.isActive){
            screenPicker.isActive = true
            screenPicker.add(self)
        }
        
        if let runningStream {
            configurePicker(for: runningStream)
            screenPicker.present(for: runningStream, using: .window)
        } else {
            screenPicker.configuration = windowPickerConfiguration()
            screenPicker.present(using: .window)
        }
    }
    
    func getFrameSequence() -> AsyncThrowingStream<FrameType, Error> {
        return AsyncThrowingStream<FrameType, Error> { continuation in
            let callbacks = StreamFrameCallbacks(
                onFrame: { frame in
                    continuation.yield(frame)
                },
                getCurrentFilter: { [weak self] in
                    await MainActor.run {
                        self?.currentFilter
                    }
                },
                onStreamStop: {
                    Task { @MainActor in
                        self.runningStream = nil
                        self.currentFilter = nil
                    }
                }
            )
            self.scDelegate = StreamToFramesDelegate(recorder: avRecorder, callbacks: callbacks)
        }
    }
}

func rectsApproxEqual(_ r1: CGSize, _ r2: CGSize) -> Bool{
    return (abs(r1.width - r2.width) + abs(r1.height - r2.height)) < 5 //+/- ~ 2 pixels in each dimension seems fine
}

let FrameScaling = 2

func getStreamConfig(_ streamDimensions: CGSize) -> SCStreamConfiguration {
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

private func getCurrentlySharedWindow(size: CGSize) async -> [SCWindow] {
    do {
        
        //Try to figure out window is about to get swapped out
        let allContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        let allWindows = allContent.windows
        let matchingWindows = allWindows.filter {window in window.isActive && window.frame.size == size}
        return matchingWindows
        
    } catch {
        Logger().debug("failed figuring out what the old window was: \(error)")
        return []
    }
}


//from https://stackoverflow.com/questions/38318387/swift-cgimage-to-cvpixelbuffer
func pixelBufferFromCGImage(image: CGImage) -> CVPixelBuffer? {
    
    guard let imageData = image.dataProvider?.data,
        let mutableData = CFDataCreateMutableCopy(
            kCFAllocatorDefault,
            0,
            imageData
        ),
        let baseAddress = CFDataGetMutableBytePtr(mutableData)
    else {
        return nil
    }
    
    var pxbuffer: CVPixelBuffer? = nil
    let retainedData = Unmanaged.passRetained(mutableData)
    let releaseRefCon = retainedData.toOpaque()
    
    let releaseCallback: CVPixelBufferReleaseBytesCallback = { releaseRefCon, _ in
        guard let releaseRefCon else { return }
        Unmanaged<CFMutableData>.fromOpaque(releaseRefCon).release()
    }
    

    let width =  image.width
    let height = image.height
    let bytesPerRow = image.bytesPerRow


    let status = CVPixelBufferCreateWithBytes(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        baseAddress,
        bytesPerRow,
        releaseCallback,
        releaseRefCon,
        nil,
        &pxbuffer
    )
    if(status != kCVReturnSuccess){
        Logger().debug("cvpbcwb failed \(status)")
    }
    return pxbuffer
}
