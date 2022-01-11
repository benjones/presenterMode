//
//  ContentView.swift
//  presenterView
//
//  Created by Ben Jones on 9/17/21.
//

import SwiftUI
import AVFoundation
import CoreMediaIO

struct ContentView: View {
    @State private var windowPreviews : [WindowPreview] = []
    
    @EnvironmentObject var globalViewModel : GlobalViewModel
    @EnvironmentObject var avDeviceManager : AVDeviceManager
    
    
    
    var stopSharingButtonDisabled: Bool {
        switch globalViewModel.mirrorStatus {
        case .notSharing:
            return true
        default:
            return false
        }
    }
    
    var body: some View {
        VStack {
            Text("Select Window to Share")
                .font(.subheadline)
                .padding()
            
            HStack {
                Button(action: refreshWindows) {
                    Text("Refresh Windows")
                    
                }
                Button(action: stopSharing) {
                    Text("Stop Sharing")
                }.disabled(stopSharingButtonDisabled)
            }  .font(.subheadline)
            
            ScrollView{
                LazyVGrid(columns: Array(repeating: GridItem.init(.fixed(300)), count: 4)){
                    ForEach(avDeviceManager.avCaptureDevices) {avWrapper in
                        VStack {
                            Image(GlobalViewModel.noPreviewAvailableImage, scale: 1.0, orientation: Image.Orientation.up, label: Text(avWrapper.device.localizedName))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 300, height: 300, alignment: .center)
                                .border(Color.white)
                            Text("\(maybeTruncate( str: avWrapper.device.localizedName))")
                                
                            
                        }.onTapGesture {
                            print("tapped on av device")
                            //shareWindow(windowPreview: windowPreview)
                        }
                        
                    }
                    ForEach(windowPreviews) { windowPreview in
                        VStack {
                            Image(windowPreview.image, scale: 1.0, orientation: Image.Orientation.up, label: Text(windowPreview.title))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 300, height: 300, alignment: .center)
                                .border(Color.white)
                            Text("\(maybeTruncate( str: windowPreview.owner)): \(maybeTruncate(str: windowPreview.title))")
                        }.onTapGesture {
                            shareWindow(windowPreview: windowPreview)
                        }
                    }
                }
            }
            .onAppear(perform: startup)
        }
    }
    
    
    func startup() -> Void {
        
        //without this ipads won't show up as capture dvices
        //        //From https://stackoverflow.com/questions/48646470/ios-device-not-listed-by-avcapturedevice-devices-unless-quicktime-is-opened
        //        var prop = CMIOObjectPropertyAddress(
        //            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
        //            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        //            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster))
        //
        //        var allow : UInt32 = 1
        //        let dataSize : UInt32 = 4
        //        let zero : UInt32 = 0
        //        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, zero, nil, dataSize, &allow)
        //
        refreshWindows();
        //print(captureDevices)
    }
    
    func refreshWindows() -> Void {
        windowPreviews = getWindowPreviews()
    }
    
    
    
    
    func stopSharing() -> Void {
        globalViewModel.stopAnimating()
        globalViewModel.mirrorStatus = .notSharing
        if let mirrorWindow = globalViewModel.mirrorWindow {
            mirrorWindow.title = "Mirrored View"
        }
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
        let mirrorWindow = getMirrorWindow()
        mirrorWindow.title = "Sharing \(maybeTruncate(str: windowPreview.owner))"
        
        globalViewModel.setWindow(wn: windowPreview.windowNumber)
        globalViewModel.mirrorStatus = .windowShare
        globalViewModel.sharedWindowData.image = windowPreview.image
        if globalViewModel.sharedWindowData.timer == nil {
            globalViewModel.sharedWindowData.timer = Timer(timeInterval: 1/30.0, repeats: true){_ in
                let frame = CGWindowListCreateImage(CGRect.null, CGWindowListOption.optionIncludingWindow, globalViewModel.windowNumber, CGWindowImageOption.bestResolution)
                if frame == nil {
                    globalViewModel.stopAnimating()
                    globalViewModel.sharedWindowData.image = GlobalViewModel.staticImage
                } else {
                    globalViewModel.sharedWindowData.image = frame!
                }
            }
        }
        
        
        RunLoop.main.add(globalViewModel.sharedWindowData.timer!, forMode: .default)
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

class PhotoDelegate : NSObject, AVCapturePhotoCaptureDelegate{
    var cv : ContentView
    init(theCV : ContentView){
        cv = theCV
        print("delegate constructed")
    }
    
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?){
        print("got the ipad photo!")
        print(photo.timestamp)
        
    }
    
    func photoOutput(_: AVCapturePhotoOutput, willBeginCaptureFor: AVCaptureResolvedPhotoSettings){
        print("starting the capture")
    }
    
    func photoOutput(_: AVCapturePhotoOutput, didFinishCaptureFor: AVCaptureResolvedPhotoSettings, error: Error?){
        print("did finish capture")
    }
    
    
}
