//
//  StreamView.swift
//  presenterMode
//
//  Created by Ben Jones on 6/13/24.
//

import SwiftUI
import OSLog

struct StreamView: NSViewRepresentable {
    
    
    @EnvironmentObject var pickerManager: ScreenPickerManager
    private let logger = Logger()
    
    private let contentLayer = CALayer()
    
    init() {
        contentLayer.contentsGravity = .resizeAspect
    }
    
    func makeNSView(context: Context) -> some NSView {
        logger.debug("Making my NSView with layer \(contentLayer)")
        let viewImpl = StreamViewImpl(layer:contentLayer)
        pickerManager.registerView(viewImpl)
        return viewImpl
    }
    
    //func updateFrame(_ frame: TODO ){}
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        logger.debug("Ignoring updateNSView call: \(nsView)")
    }
}
    class StreamViewImpl : NSView {
        
        init(layer: CALayer) {
            super.init(frame: .zero)
            //TODO use wantsUpdateLayer, etc here to trigger redraws
            self.layer = layer
            self.wantsLayer = true
            
            Logger().debug("Created NSView")
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateFrame(_ surface : IOSurface){
            self.layer?.contents = surface
        }
    }
    

