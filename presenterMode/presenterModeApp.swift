//
//  presenterModeApp.swift
//  presenterMode
//
//  Created by Ben Jones on 9/17/21.
//

import SwiftUI
import ScreenCaptureKit
import OSLog

@main
struct presenterModeApp: App {
    //@State var globalViewModel = GlobalViewModel()
    @State var avDeviceManager = AVDeviceManager()
    
    @Environment(\.openWindow) private var openWindowEnv
    
    @State var pickerManager = ScreenPickerManager()
    
//    @State private var screenRecorder: ScreenRecorder
//    
//    init(){
//        screenRecorder = ScreenRecorder()
//    }
    
    private var logger = Logger()
    
    func openWindow(){
        DispatchQueue.main.async {
            openWindowEnv(id: "mirror")
        }
    }
    
    var body: some Scene {
        

        Window("Window Picker", id: "picker") {
            ContentView()
                .environmentObject(pickerManager)
                //.environmentObject(globalViewModel)
                .environmentObject(avDeviceManager)
                .onAppear(){
                    logger.debug("ContenView appearing")
                    pickerManager.setApp(app:self)
//                    Task{
//                        do {
//                            // If the app doesn't have screen recording permission, this call generates an exception.
//                            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
//                            logger.debug("Have sharing permissions")
//                        } catch {
//                            logger.debug("DO NOT have sharing permissions")
//                        }
//                    }
                }
        }
        
        Window("Mirror window", id: "mirror"){
//            MirrorView()
//                .environmentObject(globalViewModel)
            StreamView()
                .environmentObject(pickerManager)
                .environmentObject(avDeviceManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

