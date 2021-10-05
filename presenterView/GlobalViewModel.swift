//
//  GlobalViewModel.swift
//  presenterView
//
//  Created by Ben Jones on 10/1/21.
//

import Foundation
import AppKit

class GlobalViewModel : NSObject, ObservableObject {
    
    @Published var mirrorWindow : NSWindow?
    @Published var windowNumber : CGWindowID = 0
    @Published var image : CGImage = CGImage(pngDataProviderSource: CGDataProvider(data: NSDataAsset(name: "static")!.data as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    @Published var timer : Timer?
    
    func setMirror(window: NSWindow){
        mirrorWindow = window
        mirrorWindow!.delegate = self
    }
    
    func setWindow(wn: CGWindowID){
        windowNumber = wn
    }
}

extension GlobalViewModel : NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("will clsoe notification: \(notification)")
        if let window = notification.object as? NSWindow {
            print("closing window:")
            print(window)
            if window == mirrorWindow {
                mirrorWindow = nil
                print("closed mirror window")
                if timer != nil {
                    timer?.invalidate()
                }
                
            }
        }
      }
    func windowWillResize(_ sender: NSWindow,
                          to frameSize: NSSize) -> NSSize {
        print("will resize handler")
        return frameSize
    }
}
