//
//  RecordingControlsView.swift
//  presenterMode
//
//  Created by Ben Jones on 10/23/24.
//

import SwiftUI
import OSLog
import AVFoundation

struct RecordingControlsView : View {
    private let logger = Logger()
    let startRecording: (URL, AVCaptureDevice?) -> Void
    let stopRecording: () -> Void
    @EnvironmentObject var recordingState: RecordingState
    @Binding var selectedAudio: AVWrapper?
    @Binding var audioDevices: [AVWrapper]
    
    var body: some View {
        HStack {
            Text("Video Recording")
                .font(.title2)
                .padding(.horizontal, 16)
            
            Divider()
            
            if(!recordingState.recording){
                Button(action: {
                    let url = showSavePanel()
                    let str: String = url?.absoluteString ?? "nil"
                    logger.debug("URL: \(str)")
                    if let url {
                        startRecording(url, selectedAudio?.device)
                    }
                }){
                    Image(systemName: "record.circle.fill")
                        .foregroundStyle(.red)
                }
            } else {
                Button(action: {
                    stopRecording()
                }){
                    Image(systemName: "stop")
                        .foregroundStyle(.red)
                }
            }
            
            Picker("Audio input", selection: $selectedAudio){
                ForEach(audioDevices, id: \.self){ dev in
                    Text(dev.device.localizedName).tag(dev)
                }
                Text("None").tag(nil as AVWrapper?)
            }
            .pickerStyle(.menu)
            //seems happy but makes sure we auto-select the internal microphone instead of "None" on load
            .onChange(of: audioDevices){ oldVal, newVal in
                if(oldVal.isEmpty){
                    selectedAudio = newVal[0]
                }
            }
            .disabled(recordingState.recording)
            
            Gauge(value: recordingState.audioLevel, in: Float(0)...Float(1)){
                Text("dB")
            }
            .gaugeStyle(AccessoryCircularGaugeStyle())
            .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
            .scaleEffect(0.5) //no better way to resize it apparently
            
        }.frame(maxHeight: 80)
    }
}



