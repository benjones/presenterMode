//
//  StreamView.swift
//  presenterMode
//
//  Created by Ben Jones on 6/13/24.
//

import SwiftUI
import OSLog
import AVFoundation

struct StreamView: NSViewRepresentable {
    
    
    @EnvironmentObject var pickerManager: ScreenPickerManager
    @EnvironmentObject var avDeviceManager: AVDeviceManager
    private let logger = Logger()
    
    //TODO REPLACE WITH AVVideoCapturePreviewLayer when necessary
    
    private let contentLayer = CALayer()
    private var avLayer: AVCaptureVideoPreviewLayer?
    init() {
        contentLayer.contentsGravity = .resizeAspectFill
    }
    
    mutating func streamAVDevice(streamViewImpl: StreamViewImpl, device: AVCaptureDevice){
        logger.debug("starting to stream AV device!")
        self.avDeviceManager.setupCaptureSession(device: device)
        self.avLayer = AVCaptureVideoPreviewLayer(session: avDeviceManager.avCaptureSession!)
        self.avLayer!.contentsGravity = .resizeAspect
        self.avLayer!.videoGravity = .resizeAspect
                
        streamViewImpl.layer = self.avLayer
        logger.debug("set streaming layer to AV")
    }
    
    mutating func streamWindow(streamViewImpl: StreamViewImpl){
        streamViewImpl.layer = self.contentLayer
    }
    
    
    func makeNSView(context: Context) -> some NSView {
        logger.debug("Making my NSView with layer \(contentLayer)")
        let viewImpl = StreamViewImpl(layer:contentLayer)
        pickerManager.registerView(self, viewImpl)
        return viewImpl
    }
    
    //func updateFrame(_ frame: TODO ){}
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        let viewsize = nsView.frame.size
        logger.debug("updatensview with its framesize: \(viewsize.width) x \(viewsize.height)")
    }
    
    private var frameSize = CGSize(width: 0, height: 0)
    private var croppedFrames = 0
    private var uncroppedFrames = 0
    mutating func updateFrame(_ cgImage : FrameType){
        switch(cgImage){
        case .uncropped(let iosurf):
            self.contentLayer.contents = iosurf
//            self.uncroppedFrames += 1
//            let uf = self.uncroppedFrames
//            if(uf % 100 == 0){
//                logger.debug(" \(uf) uncropped frames")
//            }
        case .cropped(let cgImage):
            self.contentLayer.contents = cgImage
//            self.croppedFrames += 1
//            let cf = self.croppedFrames
//            if(cf % 100 == 0){
//                logger.debug(" \(cf) cropped frames")
//            }
        }
        let framesize = self.contentLayer.frame.size
        if(framesize != self.frameSize){
            self.frameSize = framesize
            logger.debug("new layer frame size: \(framesize.width) x \(framesize.height)")
        }
    }
}
class StreamViewImpl : NSView {
    
    init(layer: CALayer) {
        super.init(frame: .zero)
        self.layer = layer
        self.wantsLayer = true
        self.layerContentsPlacement = .scaleProportionallyToFit
        
        Logger().debug("Created NSView")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}


