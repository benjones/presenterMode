//
//  Capture.swift
//  presenterView
//
//  Created by Ben Jones on 9/30/21.
//

import Foundation

import Cocoa
import AVFoundation
import SwiftUI
import ScreenCaptureKit
import Combine
import OSLog

struct WindowPreview : Identifiable {
    var owner : String
    var title : String
    var windowNumber : CGWindowID
    var image : CGImage
    
    var id :  CGWindowID { return windowNumber}
    
}

//func windowPreviewFromIpad(device: AVCaptureDevice) -> WindowPreview {
//    var name = device.localizedName
//    AVCapturePhoto
//}

func getWindowPreviews() -> [WindowPreview]{
    CGRequestScreenCaptureAccess()
    let cgWindowListInfo = CGWindowListCopyWindowInfo(CGWindowListOption.init([ CGWindowListOption.excludeDesktopElements,CGWindowListOption.optionAll]), kCGNullWindowID)
    
    
    let labeledWindows = (cgWindowListInfo as! [[String : AnyObject]]).filter({dict in
        let title = dict["kCGWindowName"] as? String
        return title != nil && title!.count > 0
    })
    
    let threshold = 256
    let bigWindows = labeledWindows.filter({dict in
        let bounds = dict["kCGWindowBounds"]! as! [String : Int]
        return bounds["Width"]! >= threshold && bounds["Height"]! >= threshold
    })
    
    return bigWindows.compactMap({xcw -> WindowPreview? in
        let owner = xcw["kCGWindowOwnerName"]! as! String
        let windowNumber = xcw["kCGWindowNumber"]! as! CGWindowID
        let windowName = xcw["kCGWindowName"]! as! String
        
        let image = CGWindowListCreateImage(CGRect.null, CGWindowListOption.optionIncludingWindow, xcw["kCGWindowNumber"]! as! CGWindowID, CGWindowImageOption.nominalResolution)
        if image == nil {
            return nil
        }
        
        return WindowPreview(owner: owner, title: windowName, windowNumber: windowNumber, image: image!)
    })
}



func maybeTruncate(str: String, limit: Int = 20) -> String {
    if str.count < limit {
        return str
    } else {
        return String(str[..<str.index(str.startIndex, offsetBy: limit)])
    }
}


/// Capture delegate/Stream outputter.  For now will draw the frame directly onto the layer
class StreamCaptureDelegate: NSObject, SCStreamOutput, SCStreamDelegate {
    
    var layer: CALayer
    
    private var logger = Logger()
    
    init(layer: CALayer) {
        self.layer = layer
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of: SCStreamOutputType){
        logger.debug("got a stream frame!")
        guard buffer.isValid else { return }
        guard of == SCStreamOutputType.screen else { return }
        
        //extract the image
        guard let pixelBuffer = buffer.imageBuffer else {
            logger.error("pixel buffer was nil")
            return
        }
        
        guard let surface: IOSurface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            logger.error("Couldn't get IOSurface")
            return
        }
        
        layer.contents = surface
        
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.debug("STREAM STOPPED WITH ERROR: \(error)")
    }
    
    
}
