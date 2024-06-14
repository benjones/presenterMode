//
//  ScreenPickerManager.swift
//  presenterMode
//
//  Created by Ben Jones on 6/13/24.
//

import ScreenCaptureKit
import OSLog
import SwiftUI


class ScreenPickerManager: NSObject, ObservableObject, SCContentSharingPickerObserver {
    
    private let logger = Logger()
    private let screenPicker = SCContentSharingPicker.shared
    private let scConfig = {
        let conf = SCStreamConfiguration()
        conf.capturesAudio = false
        conf.width = 640
        conf.height = 480
        //60FPS
        conf.minimumFrameInterval = CMTime(value:1, timescale: 60)
        conf.queueDepth = 5 //wait to process up to 5 frames
        return conf
    }()
    
    private var layer: CALayer?
    private var scDelegate: StreamCaptureDelegate?
    private let videoSampleBufferQueue = DispatchQueue(label: "edu.utah.cs.benjones.VideoSampleBufferQueue")
    private var runningStream: SCStream?
    private var app: presenterModeApp?
    
    
    
    
    
    func attachTo(surface contentLayer: CALayer) {
        //TODO: Do we need to clear the old one?
        self.layer = contentLayer
        
        logger.debug("attaching picker manager to layer: \(self.layer)")
        self.scDelegate =  StreamCaptureDelegate(layer:self.layer!)
        logger.debug("using delegate: \(self.scDelegate)")

    }
    
    func setApp(app:presenterModeApp){
        self.app = app
    }
    
    
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        logger.debug("Cancelled!!")
    }
    
    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        logger.debug("Updated!")
        logger.debug("Filter rect: \(filter.contentRect.debugDescription) scale: \(filter.pointPixelScale) iswindow?: \(filter.style == .window)")
        app?.openWindow()
        logger.debug("Stream? : \(stream)")
        guard stream == nil else {
            logger.debug("TODO: Stream is not nil")
            return
        }
        
        do {
            self.runningStream = SCStream(filter: filter, configuration: scConfig, delegate: scDelegate!)
            logger.debug("using delegate: \(self.scDelegate)")
            try runningStream!.addStreamOutput(scDelegate!, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
            runningStream!.startCapture()
            logger.debug("capturing should be started: \(self.runningStream)")
        } catch {
            logger.error("Error setting up stream: \(error)")
        }
        
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
