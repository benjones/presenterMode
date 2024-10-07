//
//  StreamView.swift
//  presenterMode: UI for the mirror window
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
    
    private let contentLayer = CALayer() //layer for SCKit stuff
    init() {
        contentLayer.contentsGravity = .resizeAspectFill
    }
    
    mutating func streamAVDevice(streamViewImpl: StreamViewImpl, device: AVCaptureDevice, avMirroring: Bool) {
//        var layer: AVCaptureVideoPreviewLayer?
//        DispatchQueue.global(qos:.background).sync {
//            logger.debug("starting to stream AV device!")
//            layer = self.avDeviceManager.setupCaptureSession(device: device, screenPickerManager: pickerManager)
//        }
//        self.avLayer = layer
//        streamViewImpl.layer = self.avLayer
        self.avDeviceManager.setupCaptureSession(device: device, screenPickerManager: pickerManager)
        setAVMirroring(mirroring: avMirroring)
    }
    
    func setAVMirroring(mirroring: Bool){
        //contentLayer.anchorPoint = CGPoint(x:0.5, y:0.5)
        contentLayer.transform = if mirroring {
            CATransform3DConcat(CATransform3DMakeScale(  -1, 1, 1),CATransform3DMakeTranslation( contentLayer.bounds.width,0,0)) }
            //CATransform3DTranslate( CATransform3DMakeScale(-1, 1, 1), 1, 0, 0)}
        else { CATransform3DIdentity }
        
    }

    
    func makeNSView(context: Context) -> some NSView {
        let viewImpl = StreamViewImpl(layer:contentLayer)
        pickerManager.registerView(self, viewImpl)
        return viewImpl
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        //ignored
        let viewsize = nsView.frame.size
        logger.debug("updatensview with its framesize: \(viewsize.width) x \(viewsize.height)")
    }

    mutating func updateFrame(_ cgImage : FrameType){
        switch(cgImage){
        case .uncropped(let iosurf):
            self.contentLayer.contents = iosurf
        case .cropped(let cgImage):
            self.contentLayer.contents = cgImage
        }
    }
}
class StreamViewImpl : NSView {
    
    init(layer: CALayer) {
        super.init(frame: .zero)
        self.layer = layer
        self.wantsLayer = true
        self.layerContentsPlacement = .scaleProportionallyToFit
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}


