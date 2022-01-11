//
//  GlobalViewModel.swift
//  presenterView
//
//  Created by Ben Jones on 10/1/21.
//

import Foundation
import AppKit
import AVFoundation

struct SharedWindowData {
    var image : CGImage
    var timer : Timer?
}

struct SharedAVData {
    var captureSession : AVCaptureSession?
}

enum MirrorStatus {
    case notSharing
    case windowShare
    case sharedAVData
}

class GlobalViewModel : NSObject, ObservableObject {
    
    public static let staticImage: CGImage = CGImage(pngDataProviderSource: CGDataProvider(data: NSDataAsset(name: "static")!.data as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    
    public static let noPreviewAvailableImage: CGImage = CGImage(pngDataProviderSource: CGDataProvider(data: NSDataAsset(name: "noPreviewAvailable")!.data as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    
    
    @Published var mirrorWindow : NSWindow?
    @Published var windowNumber : CGWindowID = 0
    @Published var mirrorStatus : MirrorStatus = MirrorStatus.notSharing
    //these should be part of the MirrorStatus enum but they can't be modified, so ...
    @Published var sharedWindowData = SharedWindowData(image: staticImage, timer: nil)
    @Published var sharedAVData = SharedAVData(captureSession: nil)
//    @Published var image : CGImage = staticImage
//    @Published var timer : Timer?

    
    
    func setMirror(window: NSWindow){
        mirrorWindow = window
        mirrorWindow!.delegate = self
    }
    
    func setWindow(wn: CGWindowID){
        windowNumber = wn
    }
    
    func stopAnimating(){
        switch mirrorStatus {
        case .notSharing: break
            //nothing to do
        case .windowShare:
            sharedWindowData.timer?.invalidate()
            sharedWindowData.timer = nil
            mirrorStatus = .notSharing
            break;
        case .sharedAVData:
            break;
        }
        
    }
}

extension GlobalViewModel : NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == mirrorWindow {
                mirrorWindow = nil
                stopAnimating()
            }
        }
    }
}
