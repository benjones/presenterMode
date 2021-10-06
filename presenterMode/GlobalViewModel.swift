//
//  GlobalViewModel.swift
//  presenterView
//
//  Created by Ben Jones on 10/1/21.
//

import Foundation
import AppKit

class GlobalViewModel : NSObject, ObservableObject {
    
    public static let staticImage: CGImage = CGImage(pngDataProviderSource: CGDataProvider(data: NSDataAsset(name: "static")!.data as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    
    @Published var mirrorWindow : NSWindow?
    @Published var windowNumber : CGWindowID = 0
    @Published var image : CGImage = staticImage
    @Published var timer : Timer?
    
    func setMirror(window: NSWindow){
        mirrorWindow = window
        mirrorWindow!.delegate = self
    }
    
    func setWindow(wn: CGWindowID){
        windowNumber = wn
    }
    
    func stopAnimating(){
        timer?.invalidate()
        timer = nil
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
