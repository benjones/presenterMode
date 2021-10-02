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
    
    func setMirror(window: NSWindow){
        mirrorWindow = window
        mirrorWindow!.delegate = self
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
            }
        }
      }
}
