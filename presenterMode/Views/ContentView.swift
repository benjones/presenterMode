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
import AppKit

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
    
    @Binding var avMirroring: Bool
    @State private var selectedAudio: AVWrapper?
    
    private let logger = Logger()
    
    var body: some View {
        VStack {
            HStack{
                
                AVDeviceListView(captureDevices: avDeviceManager.avCaptureDevices){ device in
                    Task {
                        await windowOpener.openWindow()
                        streamManager.streamAVDevice(
                            device: device.device,
                            avMirroring: avMirroring)
                    }
                }
                .environmentObject(avDeviceManager)
                
                Divider()
                
                HistoryView(
                    streamManager: streamManager,
                    entries: streamManager.history.reversed()){ entry in
                    Task {
                        await windowOpener.openWindow()
                        streamManager.setFilterForStream(
                            filter: SCContentFilter(
                                desktopIndependentWindow: entry.scWindow))
                    }
                }
            }
            
            Divider()
            
            RecordingControlsView(selectedAudio: $selectedAudio,
                                  audioDevices: $avDeviceManager.avAudioDevices)
            .environmentObject(streamManager)
        }
        .onAppear(){
            streamManager.present()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSWindow.willCloseNotification)) { notification in
                let window = notification.object as? NSWindow
                if(window?.title == presenterModeApp.pickerWindowTitle){
                    streamManager.stopRecording()
                } else {
                    logger.debug("not the main window")
                }
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

