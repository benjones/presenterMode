//
//  ScreenPickerManager.swift
//  presenterMode
//
//  Created by Ben Jones on 6/13/24.
//

import ScreenCaptureKit
import OSLog
import SwiftUI
import AVFoundation
import Combine

enum FrameType {
    case uncropped(IOSurface)
    case cropped(CGImage)
}

let sharingStoppedImage: CGImage = CGImage(
    pngDataProviderSource: CGDataProvider(data: NSDataAsset(name: "sharingStopped")!.data as CFData)!,
    decode: nil, shouldInterpolate: true, intent: .defaultIntent)!


@MainActor
class StreamManager: NSObject, ObservableObject, SCContentSharingPickerObserver {
    
    private let historyManager = HistoryManager()
    var history: [HistoryEntry] {
        historyManager.entries
    }
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
    private var historyObservation: AnyCancellable?
    
    
    init(avManager: AVDeviceManager, windowOpener: WindowOpener) {
        self.avDeviceManager = avManager
        self.windowOpener = windowOpener
        super.init()
        self.historyObservation = historyManager.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
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
    
    //ContentSharingPickerObserver methods
    
    //force these to run on MainActor
    
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
            //do nothing . User cancelled while selecting content, but we don't care
    }
    
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
            self.handleContentSharingPickerUpdate(filter: filter, stream: stream)
        }
    }
    
    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in
            //not sure when/how this could happen
            logger.debug("Picker start failed failed: \(error)")
        }
    }
    
    
    
    private func handleContentSharingPickerUpdate(filter: SCContentFilter, stream: SCStream?) {
        
        logger.debug("Updated from picker!")
        logger.debug("Filter rect: \(filter.contentRect.debugDescription) size: \(filter.contentRect.size.debugDescription) scale: \(filter.pointPixelScale) iswindow?: \(filter.style == .window)")
        logger.debug("stream: \(stream)")
        
        //don't expect either of these things to ever happen
        if(stream == nil && runningStream != nil){
            logger.debug("CSP stream is nil, but not the running stream! \(self.runningStream)")
        } else if(stream != self.runningStream){
            logger.debug("CSP stream and self.running stream are different! cspStream: \(stream) self.stream: \(self.runningStream)")
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
            await historyManager.update(filter: filter)
            
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

