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
    
    @Environment(\.openWindow) private var openWindow
    
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
                            openWindow(id: "mirror")
                            shareAVDevice(device: avWrapper.device)
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
                            openWindow(id: "mirror")
                            shareWindow(windowPreview: windowPreview)
                        }
                    }
                }
            }
            .onAppear(perform: startup)
        }
    }
    
    
    func startup() -> Void {
        
        refreshWindows();

    }
    
    func refreshWindows() -> Void {
        windowPreviews = getWindowPreviews()
    }
    
    func stopSharing() -> Void {
        switch globalViewModel.mirrorStatus {
        case .notSharing: break
            //nothing to do
        case .windowShare:
            globalViewModel.stopAnimating()
            break;
        case .sharedAVData:
            avDeviceManager.stopSharing()
            break;
        }
       
        globalViewModel.stopSharing()
    }
    
   
    
    func shareWindow(windowPreview : WindowPreview) -> Void {
        stopSharing()
        
        globalViewModel.setWindow(wn: windowPreview.windowNumber, title: maybeTruncate(str: windowPreview.owner))
        globalViewModel.sharedWindowData.image = windowPreview.image
        if globalViewModel.sharedWindowData.timer == nil {
            globalViewModel.sharedWindowData.timer = Timer(timeInterval: 1/30.0, repeats: true){_ in
                let frame = CGWindowListCreateImage(CGRect.null, CGWindowListOption.optionIncludingWindow, globalViewModel.sharedWindowData.windowNumber, CGWindowImageOption.bestResolution)
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
    
    func shareAVDevice(device: AVCaptureDevice) -> Void {
        stopSharing()
        if avDeviceManager.setupCaptureSession(device: device) {
            globalViewModel.setSharingAVDevice(title: maybeTruncate(str: device.localizedName))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
