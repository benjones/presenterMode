//
//  ContentView.swift
//  presenterView
//
//  Created by Ben Jones on 9/17/21.
//

import SwiftUI

struct ContentView: View {
    @State private var windowPreviews : [WindowPreview] = []
    
    @EnvironmentObject var globalViewModel : GlobalViewModel
    
    var body: some View {
        VStack {
            Text("Presenter View")
                .font(.title)
                .padding()
            
            Text("Select Window to Share")
                .font(.subheadline)
                .padding()
            
            Button(action: refreshWindows) {
                Text("Refresh Windows")
                    .font(.subheadline)
            }
            
            ScrollView{
                LazyVGrid(columns: Array(repeating: GridItem.init(.fixed(300)), count: 4)){
                    ForEach(windowPreviews) { windowPreview in
                        VStack {
                            Image(windowPreview.image, scale: 1.0, orientation: Image.Orientation.up, label: Text(windowPreview.title))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 300, height: 300, alignment: .center)
                                .border(Color.white)
                            Text("\(windowPreview.owner): \(windowPreview.title)")
                        }.onTapGesture {
                            shareWindow(windowPreview: windowPreview)
                        }
                    }
                }.onAppear(perform: refreshWindows)
            }
        }
    }
    
    func refreshWindows() -> Void {
        windowPreviews = getWindowPreviews()
    }
    
    func shareWindow(windowPreview : WindowPreview) -> Void {
        print("sharing \(windowPreview)")
        
        
        if let mirrorWindow = globalViewModel.mirrorWindow {
            mirrorWindow.orderFrontRegardless()
        } else {
            let mirrorWindow = NSWindow( contentRect: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                                     styleMask: [.titled, .closable, .miniaturizable, .fullScreen, .resizable],
                                     backing: .buffered, defer: false)
            mirrorWindow.contentView = NSHostingView(rootView: MirrorView())
            mirrorWindow.isRestorable = false;
            mirrorWindow.makeKeyAndOrderFront(nil)
            mirrorWindow.setFrameTopLeftPoint(NSPoint(x:100,y:100))
            mirrorWindow.isReleasedWhenClosed = false
            globalViewModel.setMirror(window: mirrorWindow)
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
