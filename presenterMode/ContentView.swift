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
    
    @EnvironmentObject var streamManager: StreamManager
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
                                    streamManager.streamAVDevice(device: avWrapper.device,
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
                        
                        ForEach(streamManager.history.reversed(), id: \.self.scWindow.windowID){ (historyEntry :HistoryEntry) in
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
                                    streamManager.setFilterForStream(filter: SCContentFilter(desktopIndependentWindow: historyEntry.scWindow))
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
                if(!streamManager.recording){
                    Button(action: {
                        let url = showSavePanel()
                        let str: String = url?.absoluteString ?? "nil"
                        logger.debug("URL: \(str)")
                        if(url != nil){
                            streamManager.startRecording(url: url!, audioDevice: selectedAudio?.device)
                        }
                    }){
                        Image(systemName: "record.circle.fill")
                            .foregroundStyle(.red)
                    }
                } else {
                    Button(action: {
                        streamManager.stopRecording()
                    }){
                        Image(systemName: "stop")
                            .foregroundStyle(.red)
                    }
                }
                Picker("Audio input", selection: $selectedAudio){
                    ForEach(avDeviceManager.avAudioDevices, id: \.self){ dev in
                        Text(dev.device.localizedName).tag(dev)
                    }
                    Text("None").tag(nil as AVWrapper?)
                }
                .pickerStyle(.menu)
                //seems happy but makes sure we auto-select the internal microphone instead of "None" on load
                .onChange(of: avDeviceManager.avAudioDevices){ oldVal, newVal in
                    if(oldVal.isEmpty){
                        selectedAudio = newVal[0]
                    }
                }

                Gauge(value: streamManager.audioLevel, in: Float(0)...Float(1)){
                    Text("dB")
                }
                .gaugeStyle(AccessoryCircularGaugeStyle())
                .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
                .scaleEffect(0.5) //no better way to resize it apparently
                
            }.frame(maxHeight: 80)
        }
        .onAppear(){
            streamManager.present()
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
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy_MM_dd_HH_mm"
        return formatter
    }()
    let dateString = dateFormatter.string(from: Date.now)
    
    savePanel.nameFieldStringValue = "PMRecording_\(dateString).mp4"
    let response = savePanel.runModal()
    return response == .OK ? savePanel.url : nil
}

