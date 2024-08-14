//
//  presenterModeApp.swift
//  presenterMode
//
//  Created by Ben Jones on 9/17/21.
//

import SwiftUI
import ScreenCaptureKit
import OSLog

//THIS IS A HACK BECAUSE THE SECOND WINDOW OBJECT
//CAN'T BE MAXIMIZED
class WindowOpener: NSObject, ObservableObject {
    @Environment(\.openWindow) private var openWindowEnv
    private var isWindowOpen = false
    @MainActor func openWindow() async {
        if(!isWindowOpen){
            Logger().debug("opening a new window")
            openWindowEnv(id: "mirror")
        } else {
            Logger().debug("skipping openWindow... already open")
        }
    }
    func updateWindowStatus(opened: Bool){
        self.isWindowOpen = opened
    }
}

@main
struct presenterModeApp: App {
    //@State var globalViewModel = GlobalViewModel()
    @State var avDeviceManager: AVDeviceManager
    
    @State var pickerManager: ScreenPickerManager
    @State var windowOpener = WindowOpener()
    
    init() {
        let deviceManager = AVDeviceManager()
        self.avDeviceManager = deviceManager
        self.pickerManager = ScreenPickerManager(avManager: deviceManager)
    }
    
//    @State private var screenRecorder: ScreenRecorder
//    
    
//    init(){
//        screenRecorder = ScreenRecorder()
//    }
    
    //TODO: pass this as an enviornment object
    func openWindow() async {
        await windowOpener.openWindow()
    }
    
    private var logger = Logger()
    
    
    
    var body: some Scene {
        
        
        Window("Window Picker", id: "picker") {
            ContentView()
                .environmentObject(pickerManager)
                .environmentObject(avDeviceManager)
                .environmentObject(windowOpener)
                .onAppear(){
                    logger.debug("ContenView appearing")
                    pickerManager.setApp(app:self)
                }
        }
        .defaultSize(width: 720, height: 480)
        
        //This and the windowOpener is a hack because the second Window cannot be maximized
        //by default
        WindowGroup("Mirror window", id: "mirror"){
            //            MirrorView()
            //                .environmentObject(globalViewModel)
            StreamView()
                .environmentObject(pickerManager)
                .environmentObject(avDeviceManager)
                .environmentObject(windowOpener)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear(perform: {windowOpener.updateWindowStatus(opened: true)})
                .onDisappear(perform: { windowOpener.updateWindowStatus(opened: false)})
        }
        .defaultSize(width: 1920, height: 1080)

        
        // in future version: .restorationBehavior(.disabled)
    }
}

