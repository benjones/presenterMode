//
//  Capture.swift
//  presenterView
//
//  Created by Ben Jones on 9/30/21.
//

import Foundation

import Cocoa

struct WindowPreview : Identifiable {
    var owner : String
    var title : String
    var windowNumber : CGWindowID
    var image : CGImage
    
    var id :  CGWindowID { return windowNumber}
    
}

func getWindowPreviews() -> [WindowPreview]{
    
    //let runningApps = NSWorkspace.shared.runningApplications
    
    
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
    
    print("\(bigWindows.count) big windows")
    
    return bigWindows.compactMap({xcw -> WindowPreview? in
        //print(xcw)
        
        let owner = xcw["kCGWindowOwnerName"]! as! String
        let windowNumber = xcw["kCGWindowNumber"]! as! CGWindowID
        let windowName = xcw["kCGWindowName"]! as! String
        
        let image = CGWindowListCreateImage(CGRect.null, CGWindowListOption.optionIncludingWindow, xcw["kCGWindowNumber"]! as! CGWindowID, CGWindowImageOption.nominalResolution)
        if image == nil {
            return nil
        }

/*        let path = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)
        print(path)
        let fullPath = path.first!.appendingPathComponent("presenterMode/\(owner)_\(windowNumber).png")
        
        let destination = CGImageDestinationCreateWithURL(fullPath as CFURL, kUTTypePNG, 1, nil)!
        CGImageDestinationAddImage(destination, image!, nil)
        CGImageDestinationFinalize(destination)
 */
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
