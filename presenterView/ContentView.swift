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
    
    func getMirrorWindow() -> NSWindow {
        if let mirrorWindow = globalViewModel.mirrorWindow {
            return mirrorWindow
        } else {
            let mirrorWindow = MirrorView().environmentObject(globalViewModel).openNewWindow()
            globalViewModel.setMirror(window: mirrorWindow)
            return mirrorWindow
        }
    }
    
    func shareWindow(windowPreview : WindowPreview) -> Void {
        print("sharing \(windowPreview)")
//
//        if let url = URL(string: "PresenterMode://MirrorView") { //replace myapp with your app's name
//                    let res = NSWorkspace.shared.open(url)
//                }
//
        let mirrorWindow = getMirrorWindow()
        print(mirrorWindow.contentView!)
        globalViewModel.setWindow(wn: windowPreview.windowNumber)
        globalViewModel.image = windowPreview.image
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


extension View {
    private func newWindowInternal(with title: String) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 20, y: 20, width: 680, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.center()
        window.isReleasedWhenClosed = false
        window.title = title
        window.makeKeyAndOrderFront(nil)
        return window
    }
    
    func openNewWindow(with title: String = "Mirrored View") -> NSWindow{
        let ret = self.newWindowInternal(with: title)
        ret.contentView = NSHostingView(rootView: self)
        return ret
    }
}
