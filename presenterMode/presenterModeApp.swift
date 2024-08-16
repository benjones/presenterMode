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
    private var isWindowOpen = false
    @MainActor func openWindow(action: OpenWindowAction) async {
        if(!isWindowOpen){
            Logger().debug("opening a new window")
            action(id: "mirror")
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
    @Environment(\.openWindow) private var openWindowEnv
    
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
    @MainActor func openWindow() async {
        await windowOpener.openWindow(action: openWindowEnv)
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

