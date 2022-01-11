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
        WindowGroup {
            ContentView()
                .environmentObject(globalViewModel)
                .environmentObject(avDeviceManager)
        }
        
    }
}

