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
    
    func makeNSView(context: Context) -> some NSView {
        pickerManager.attachTo(surface:contentLayer)
        logger.debug("Making my NSView with layer \(contentLayer)")
        return StreamViewImpl(layer:contentLayer)
    }
    
    //func updateFrame(_ frame: TODO ){}
    
    func updateNSView(_ nsView: NSViewType, context: Context) { 
        logger.debug("Ignoring updateNSView call")
    }
    
    class StreamViewImpl : NSView {
        
        init(layer: CALayer) {
            super.init(frame: .zero)
            self.layer = layer
            wantsLayer = true
            Logger().debug("Created NSView")
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
}
