//
//  ContentView.swift
//  presenterView: UI for the picker window
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

    @EnvironmentObject var pickerManager: ScreenPickerManager
    @EnvironmentObject var avDeviceManager : AVDeviceManager
    @EnvironmentObject var windowOpener: WindowOpener
    @Environment(\.openWindow) private var openWindow
    
    @Binding var avMirroring: Bool
    @State private var selectedAudio: AVWrapper?
    
    private let logger = Logger()
    
    var body: some View {
        VStack {
            HStack{
                ScrollView{
                    VStack{
                        Text("Devices")
                            .font(.title)
                        ForEach(avDeviceManager.avCaptureDevices, id: \.id) {avWrapper in
                            VStack {
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
                            }
                            
                        }
                    }.frame(minWidth:340)
                }
                
                Divider()
                
                ScrollView{
                    VStack(alignment: .center){
                        Text("Screen History")
                            .frame(idealWidth:320)
                            .font(.title)
                        
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
                                    pickerManager.setFilterForStream(filter: SCContentFilter(desktopIndependentWindow: historyEntry.scWindow))
                                }
                            }
                        }
                    }.frame(minWidth:340)
                }
                
            }
            Divider()
            HStack {
                Text("Video Recording")
                    .font(.title2)
                Divider()
                Button(action: {
                    let url = showSavePanel()
                    let str: String = url?.absoluteString ?? "nil"
                    logger.debug("URL: \(str)")
                }){
                    Image(systemName: "record.circle.fill")
                        .foregroundStyle(.red)
                }
                Picker("Audio input", selection: $selectedAudio){
                    ForEach(avDeviceManager.avAudioDevices, id: \.self){ dev in
                        Text(dev.device.localizedName).tag(dev)
                    }
                    Text("None").tag(nil as AVWrapper?)
                }
                .pickerStyle(.menu)
                
            }.frame(maxHeight: 80)
        }
        .onAppear(){
            pickerManager.present()
        }
    }
}

//from https://serialcoder.dev/text-tutorials/macos-tutorials/save-and-open-panels-in-swiftui-based-macos-apps/
func showSavePanel() -> URL? {
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.mpeg4Movie]
    savePanel.canCreateDirectories = true
    savePanel.isExtensionHidden = false
    savePanel.allowsOtherFileTypes = false
    savePanel.title = "Video Recording"
    savePanel.message = "Choose filename for video recording"
    savePanel.nameFieldLabel = "File name:"
    let response = savePanel.runModal()
    return response == .OK ? savePanel.url : nil
}

