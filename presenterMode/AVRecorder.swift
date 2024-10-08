//
//  AVRecorder.swift
//  presenterMode
//
//  Created by Ben Jones on 9/30/24.
//

import Foundation
import AVFoundation
import OSLog

class AVRecorder {
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var assetWriterInput: AVAssetWriterInput?
    private let clock = CMClockGetHostTimeClock()
    private var recordingStartTime = CMTime()
    private(set) var recording = false
    //returns true if the recording actually started
    func startRecording(url : URL) -> Bool {
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let settingsAssistant = AVOutputSettingsAssistant(preset: .preset1920x1080)?.videoSettings
            assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: settingsAssistant)
            assetWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput!, sourcePixelBufferAttributes: nil)
            assetWriter!.add(assetWriterInput!)
            assetWriter!.startWriting()
            recordingStartTime = clock.time
            assetWriter!.startSession(atSourceTime: recordingStartTime)
            recording = true
            return true
        } catch {
            Logger().error("Couldn't start asset recording: \(error)")
            recording = false
            return false
        }
    }
    
    func writeFrame(frame: CVPixelBuffer){
        assert(recording)
        assetWriterAdaptor!.append(frame, withPresentationTime: clock.time)
    }
    
    func finishRecording(){
        assetWriterInput!.markAsFinished()
        assetWriter!.finishWriting {
            Logger().debug("finished writing video file!")
            self.recording = false
        }
    }
}
