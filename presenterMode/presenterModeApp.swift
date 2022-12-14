//
//  presenterModeApp.swift
//  presenterMode
//
//  Created by Ben Jones on 9/17/21.
//

import SwiftUI


@main
struct presenterModeApp: App {
    @State var globalViewModel = GlobalViewModel()
    @State var avDeviceManager = AVDeviceManager()
    
    
    
    var body: some Scene {
        Window("Window Picker", id: "picker") {
            ContentView()
                .environmentObject(globalViewModel)
                .environmentObject(avDeviceManager)
        }
        
        Window(globalViewModel.title, id: "mirror"){
            MirrorView()
                .environmentObject(globalViewModel)
                .environmentObject(avDeviceManager)

        }
        
        
    }
}

