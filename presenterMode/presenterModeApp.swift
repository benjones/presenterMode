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
            action(id: "mirror")
        } 
    }
    func updateWindowStatus(opened: Bool){
        self.isWindowOpen = opened
    }
}

struct MirrorCommands : Commands {
    
    @Binding var mirrorAVDevice: Bool
    var body: some Commands {
        CommandGroup(before: CommandGroupPlacement.toolbar){
            Toggle("Flip Content Horizontally", isOn: $mirrorAVDevice)
        }
    }
}

@main
struct presenterModeApp: App {

    @State var avDeviceManager = AVDeviceManager()
    @Environment(\.openWindow) private var openWindowEnv
    
    @State var pickerManager: StreamManager
    @State var windowOpener = WindowOpener()
    
    init() {
        let deviceManager = AVDeviceManager()
        self.avDeviceManager = deviceManager
        self.pickerManager = StreamManager(avManager: deviceManager)
        self.pickerManager.setupTask()
    }
    
    
    //TODO: pass this as an enviornment object
    @MainActor func openWindow() async {
        await windowOpener.openWindow(action: openWindowEnv)
    }
    
    private var logger = Logger()
    
    @State private var avMirroring = false
    
    
    var body: some Scene {
        
        
        Window("Window Picker", id: "picker") {
            ContentView(avMirroring: $avMirroring)
                .environmentObject(pickerManager)
                .environmentObject(avDeviceManager)
                .environmentObject(windowOpener)
                .onAppear(){
                    pickerManager.setApp(app:self)
                }
        }
        .defaultSize(width: 720, height: 480)
        .commands{
            MirrorCommands(mirrorAVDevice: $avMirroring)
        }.onChange(of: avMirroring, initial: false){
            pickerManager.updateAVMirroring(avMirroring: avMirroring)
        }

        
        
        
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
                .onGeometryChange(for: CGSize.self){proxy in
                    
                    return proxy.size
                }  action: { newSize in
                    //if the size changes, turn off mirroring
                    //BUG: mirroring doesn't seem to work properly during resize
                    //and without this you'd have to turn it off and then on again
                    //after resize
                    avMirroring = false
                }
            
        }
        .defaultSize(width: 1920, height: 1080)
        

        
        // in future version: .restorationBehavior(.disabled)
    }
}

