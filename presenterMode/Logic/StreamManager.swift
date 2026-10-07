//
//  ScreenPickerManager.swift
//  presenterMode
//
//  Created by Ben Jones on 6/13/24.
//

import ScreenCaptureKit
import OSLog
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
class StreamManager {
    
    private let recordingState: RecordingState
    private let updateHistory: (SCContentFilter) async -> Void
    
    private let logger = Logger()
    private let screenPicker = SCContentSharingPicker.shared
    private var pickerObserverRegistered = false
    private lazy var pickerObserver = ContentSharingPickerObserver(
        didUpdate: { [weak self] filter, stream in
            self?.handleContentSharingPickerUpdate(filter: filter, stream: stream)
        },
        didFail: { [weak self] error in
            self?.logger.debug("Picker start failed failed: \(error)")
        }
    )
        

    
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
    
    private var audioMeterTask: AnyCancellable?
    private var streamMutationTask: Task<Void, Never>?
    
    private func enqueueStreamMutation(
        _ mutation: @escaping (SCStream) async throws -> Void
    ) {
        guard let stream = runningStream else { return }
        
        let previousTask = streamMutationTask
        
        streamMutationTask = Task { @MainActor [weak self, stream] in
            _ = await previousTask?.result
            
            guard
                !Task.isCancelled,
                let self,
                self.runningStream === stream
            else {
                return
            }
            
            do {
                try await mutation(stream)
            } catch is CancellationError {
                return
            } catch {
                self.logger.error("Stream mutation failed: \(error)")
            }
        }
    }
    
    
    init(
        avManager: AVDeviceManager,
        windowOpener: WindowOpener,
        recordingState: RecordingState,
        updateHistory: @escaping (SCContentFilter) async -> Void
    ) {
        self.avDeviceManager = avManager
        self.windowOpener = windowOpener
        self.recordingState = recordingState
        self.updateHistory = updateHistory
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
        recordingState.recording = avRecorder.startRecording(url: url, audioDevice: audioDevice, delegate: scDelegate!)
        
        audioMeterTask = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
            self.recordingState.audioLevel = avRecorder.audioLevels.peakLevel
        }
    }
    
    func stopRecording(){
        if(recordingState.recording) {
            avRecorder.finishRecording()
            recordingState.audioLevel = 0
            audioMeterTask?.cancel()
            recordingState.recording = false
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
    
    private func handleContentSharingPickerUpdate(filter: SCContentFilter, stream: SCStream?) {
        logger.debug("""
        Picker filter updated. isWindowStyle: \(filter.style == .window)
        windows: \(filter.includedWindows.count)
        displays: \(filter.includedDisplays.count)
        """)
        
        // The picker has already applied this filter to an existing stream.
        // Do not call updateContentFilter again.
        if let stream {
            guard stream === runningStream else {
                logger.error("Picker updated an unexpected stream: \(stream)")
                return
            }
            
            currentFilter = filter
            updatePickerStreamConfiguration(stream: stream, filter: filter)
        } else {
            // For the initial picker selection, the filter is returned before
            // there is an app-owned stream. Construct the stream with it.
            guard runningStream == nil else {
                logger.error("Picker returned no stream while a stream is already running")
                return
            }
            
            createStream(filter: filter)
            currentFilter = filter
        }
        
        Task { @MainActor in
            await windowOpener.openWindow()
            await updateHistory(filter)
        }
    }
    
    private func updatePickerStreamConfiguration(stream: SCStream, filter: SCContentFilter) {
        enqueueStreamMutation { stream in
            try await stream.updateConfiguration(
                getStreamConfig(filter.contentRect.size)
            )
        }
    }
    
    func createStream(filter: SCContentFilter){
        self.runningStream = SCStream(filter: filter, configuration: getStreamConfig(filter.contentRect.size), delegate: self.scDelegate!)
        logger.debug("created new stream: \(self.runningStream)")
        do {
            try self.runningStream?.addStreamOutput(scDelegate!, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
            self.runningStream?.startCapture()
        } catch {
            logger.debug("Start capture failed: \(error)")
        }
    }
    
    func addWindowToStream(window: SCWindow){
        if let currentFilter {
            logger.debug("filter windows: \(currentFilter.includedWindows.count)")
            logger.debug("filter displays: \(currentFilter.includedDisplays.count)")
            
            if currentFilter.includedDisplays.count > 0 {
                if currentFilter.includedDisplays.count != 1 {
                    logger.error("More than 1 display, ignoring all but the first: \(currentFilter.includedDisplays.count) displays")
                }
                
                guard let display = currentFilter.includedDisplays.first else {
                    logger.error("Current filter has no display to add a window to")
                    return
                }
                
                setFilterForStream(
                    filter: SCContentFilter(
                        display: display,
                        including: currentFilter.includedWindows + [window]
                    )
                )
            } else {
                guard let sharedWindow = currentFilter.includedWindows.first else {
                    logger.error("Current filter has no shared window")
                    return
                }
                
                let existingWindows = currentFilter.includedWindows
                
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    
                    do {
                        guard let display = try await findDisplay(containing: sharedWindow) else {
                            logger.error("Could not find display for shared window")
                            return
                        }
                        
                        setFilterForStream(
                            filter: SCContentFilter(
                                display: display,
                                including: existingWindows + [window]
                            )
                        )
                    } catch {
                        logger.error("Could not retrieve shareable content: \(error)")
                    }
                }
            }
        } else {
            switchStreamToWindow(window: window)
        }
    }
    
    func switchStreamToWindow(window: SCWindow){
        setFilterForStream(filter: SCContentFilter(desktopIndependentWindow: window))
    }
    
    func setFilterForStream(filter: SCContentFilter) {
        avDeviceManager.stopSharing()
        Task { @MainActor in
            
            await windowOpener.openWindow()
            await updateHistory(filter)
            
        }
        if(runningStream == nil){
            createStream(filter: filter)
        }
        enqueueStreamMutation { [weak self] stream in
            try await stream.updateContentFilter(filter)
            try await stream.updateConfiguration(
                getStreamConfig(filter.contentRect.size)
            )
            
            guard let self, self.runningStream === stream else { return }
            self.currentFilter = filter
        }
        
    }
    
    func present(){
        if(!screenPicker.isActive){
            screenPicker.isActive = true
        }

        if(!pickerObserverRegistered){
            screenPicker.add(pickerObserver)
            pickerObserverRegistered = true
        }

        if let runningStream {
            screenPicker.present(for: runningStream)
        } else {
            screenPicker.present()
        }
    }
    
    func getFrameSequence() -> AsyncThrowingStream<FrameType, Error> {
        return AsyncThrowingStream<FrameType, Error>(bufferingPolicy: .bufferingNewest(1)) { continuation in
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
                },
                requestConfigurationUpdate: { [weak self] size in
                    Task { @MainActor in
                        self?.enqueueStreamMutation { stream in
                            try await stream.updateConfiguration(
                                getStreamConfig(size)
                            )
                        }
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
