//
//  GlobalViewModel.swift
//  presenterView
//
//  Created by Ben Jones on 10/1/21.
//

import Foundation
import AppKit
import AVFoundation


enum SharingStatus {
    case notSharing
    case SCSharing(StreamCaptureDelegate)
}

struct SharedWindowData {
    var image : CGImage
    var timer : Timer?
    var windowNumber : CGWindowID = 0
    var title : String
}

enum MirrorStatus {
    case notSharing
    case windowShare
    case sharedAVData
}

class GlobalViewModel : /*NSObject, */ObservableObject {
    
    public static let staticImage: CGImage = CGImage(pngDataProviderSource: CGDataProvider(data: NSDataAsset(name: "static")!.data as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    
    public static let noPreviewAvailableImage: CGImage = CGImage(pngDataProviderSource: CGDataProvider(data: NSDataAsset(name: "noPreviewAvailable")!.data as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    
    @Published var mirrorStatus : MirrorStatus = MirrorStatus.notSharing
    //these should be part of the MirrorStatus enum but they can't be modified, so ...
    @Published var sharedWindowData = SharedWindowData(image: staticImage, timer: nil, title: "")
    
    @Published var title = "Mirror View: Not Sharing"
    
    func setWindow(wn: CGWindowID, title: String){
        mirrorStatus = .windowShare
        sharedWindowData.windowNumber = wn
        self.title = "Sharing \(title)"
    }
    
    func setSharingAVDevice(title: String){
        mirrorStatus = .sharedAVData
        self.title = "Sharing \(title)"
    }
    
    func stopSharing(){
        mirrorStatus = .notSharing
        self.title = "Mirror View: Not Sharing"
    }
    
    func stopAnimating(){
        sharedWindowData.timer?.invalidate()
        sharedWindowData.timer = nil
        mirrorStatus = .notSharing
        self.title = "Mirror View: Not Sharing"        
    }
   
}
