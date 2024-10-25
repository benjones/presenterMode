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
    private var action: OpenWindowAction?
    
    @MainActor func openWindow() async {
        if(!isWindowOpen){
            action!(id: "mirror")
        }
    }
    func updateWindowStatus(opened: Bool){
        self.isWindowOpen = opened
    }
    
    func setAction(action: OpenWindowAction){
        self.action = action
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

    let avDeviceManager = AVDeviceManager()
    @Environment(\.openWindow) private var openWindowEnv
    
    let streamManager: StreamManager
    let windowOpener = WindowOpener()
    
    init() {
        self.streamManager = StreamManager(avManager: avDeviceManager,
                                           windowOpener: windowOpener)
        self.streamManager.setupTask()
    }
        
    @State private var avMirroring = false
    
    static let pickerWindowTitle = "Window Picker"
    
    var body: some Scene {
        
        Window(presenterModeApp.pickerWindowTitle, id: "picker") {
            ContentView(avMirroring: $avMirroring)
                .environmentObject(streamManager)
                .environmentObject(avDeviceManager)
                .environmentObject(windowOpener)
                .onAppear(){
                    windowOpener.setAction(action: openWindowEnv)
                }
        }
        .defaultSize(width: 720, height: 480)
        .commands{
            MirrorCommands(mirrorAVDevice: $avMirroring)
        }.onChange(of: avMirroring, initial: false){
            streamManager.updateAVMirroring(avMirroring: avMirroring)
        }

        
        
        
        //This and the windowOpener is a hack because the second Window cannot be maximized
        //by default
        WindowGroup("Mirror window", id: "mirror"){
            StreamView()
                .environmentObject(streamManager)
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

