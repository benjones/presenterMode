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
    @State private var hasInitializedAudioSelection = false

    var body: some View {
        VStack(spacing: 6) {
            Text("Record to MP4 File")
                .font(.title2)

            HStack(spacing: 12) {
                if !recordingState.recording {
                    Button(action: {
                        let url = showSavePanel()
                        let str: String = url?.absoluteString ?? "nil"
                        logger.debug("URL: \(str)")
                        if let url {
                            startRecording(url, selectedAudio?.device)
                        }
                    }) {
                        Image(systemName: "record.circle.fill")
                            .foregroundStyle(recordingState.hasVideoFrame ? .red : .secondary)
                            .opacity(recordingState.hasVideoFrame ? 1 : 0.45)
                    }
                    .disabled(!recordingState.hasVideoFrame)
                    .help(recordingState.hasVideoFrame
                          ? "Start recording"
                          : "Start sharing before recording")
                } else {
                    Button(action: {
                        stopRecording()
                    }) {
                        Image(systemName: "stop")
                            .foregroundStyle(.red)
                    }
                }

                Picker("Audio input", selection: $selectedAudio) {
                    ForEach(audioDevices, id: \.self) { dev in
                        Text(dev.device.localizedName).tag(dev)
                    }
                    Text("None").tag(nil as AVWrapper?)
                }
                .pickerStyle(.menu)
                // Select the built-in microphone once the devices are available.
                .onChange(of: audioDevices, initial: true) { _, newVal in
                    guard !hasInitializedAudioSelection, !newVal.isEmpty else { return }

                    if selectedAudio == nil {
                        selectedAudio =
                            newVal.first { $0.device.deviceType == .microphone }
                            ?? newVal.first
                    }

                    hasInitializedAudioSelection = true
                }
                .disabled(recordingState.recording)

                Gauge(value: recordingState.audioLevel, in: Float(0)...Float(1)) {
                    Text("dB")
                }
                .gaugeStyle(AccessoryCircularGaugeStyle())
                .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
                .scaleEffect(0.5) //no better way to resize it apparently
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }
}



