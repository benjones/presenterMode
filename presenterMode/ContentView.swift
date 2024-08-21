//
//  ContentView.swift
//  presenterView
//
//  Created by Ben Jones on 9/17/21.
//

import SwiftUI
import AVFoundation
import CoreMediaIO
import OSLog
import ScreenCaptureKit

func maybeTruncate(str: String, limit: Int = 20) -> String {
    if str.count < limit {
        return str
    } else {
        return String(str[..<str.index(str.startIndex, offsetBy: limit)])
    }
}

struct ContentView: View {
    //@State private var windowPreviews : [WindowPreview] = []
    
    //@Binding var screenRecorder : ScreenRecorder
    @EnvironmentObject var pickerManager: ScreenPickerManager
    //@EnvironmentObject var globalViewModel : GlobalViewModel
    @EnvironmentObject var avDeviceManager : AVDeviceManager
    @EnvironmentObject var windowOpener: WindowOpener
    
    @Binding var avMirroring: Bool
    
    @Environment(\.openWindow) private var openWindow
    
    private let logger = Logger()
    

//    var stopSharingButtonDisabled: Bool {
//        switch globalViewModel.mirrorStatus {
//        case .notSharing:
//            return true
//        default:
//            return false
//        }
//    }
    
    var body: some View {
        HStack{
            ScrollView{
                Text("Devices")
                ForEach(avDeviceManager.avCaptureDevices, id: \.id) {avWrapper in
                    VStack {
//                        Image(GlobalViewModel.noPreviewAvailableImage, scale: 1.0, orientation: Image.Orientation.up, label: Text(avWrapper.device.localizedName))
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(width: 320, height: 180, alignment: .center)
//                            .border(Color.white)
                        Text("\(maybeTruncate( str: avWrapper.device.localizedName))")
                            .frame(width: 320, height: 60)
                            .background(Color.secondary)
                            .border(Color.accentColor)
                        
                        
                    }.onTapGesture {
                        Task {
                            await windowOpener.openWindow(action: openWindow)
                            pickerManager.streamAVDevice(device: avWrapper.device,
                                                         avMirroring: avMirroring)
                        }
                        //shareAVDevice(device: avWrapper.device)
                    }
                    
                }
            }
            ScrollView{
                Text("Screen History")
                ForEach(pickerManager.history.reversed(), id: \.self.scWindow.windowID){ (historyEntry :HistoryEntry) in
                    VStack {
                        if(historyEntry.preview != nil){
                            Image(historyEntry.preview!, scale: 1.0, orientation: Image.Orientation.up, label: Text("label"))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 320, height: 180, alignment: .center)
                                .border(Color.white)
                        }
                        Text("Title: \(historyEntry.scWindow.title ?? "Untitled")")
                    }.onTapGesture {
                        Task {
                            await windowOpener.openWindow(action: openWindow)
                            avDeviceManager.stopSharing()
                            pickerManager.startStreamingFromFilter(filter: SCContentFilter(desktopIndependentWindow: historyEntry.scWindow))
                        }
                    }
                }
            }
        }
        .onAppear(){
            pickerManager.present()
        }
    }
    
}

