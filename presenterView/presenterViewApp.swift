//
//  presenterViewApp.swift
//  presenterView
//
//  Created by Ben Jones on 9/17/21.
//

import SwiftUI


@main
struct presenterViewApp: App {
    @State var globalViewModel = GlobalViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(globalViewModel)
        }
//        WindowGroup("MirrorView"){
//            MirrorView()
//        }
//        .handlesExternalEvents(matching: Set(arrayLiteral: "MirrorView")) // create new window if one doesn't exist
    }
}

