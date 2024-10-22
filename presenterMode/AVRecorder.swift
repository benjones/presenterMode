//
//  AVRecorder.swift
//  presenterMode
//
//  Created by Ben Jones on 9/30/24.
//

import Foundation
import AVFoundation
import OSLog

//based on sample code from https://img.ly/blog/how-to-make-videos-from-still-images-with-avfoundation-and-swift/

class AVRecorder {
    

    private var powerMeter = PowerMeter()
    var audioLevels: AudioLevels { powerMeter.levels}
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterVideoAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var assetWriterVideoInput: AVAssetWriterInput?
    
    private var assetWriterAudioInput: AVAssetWriterInput?
    
    //for capturing audio data
    private let avCaptureSession = AVCaptureSession()
    private let audioCaptureOutput = AVCaptureAudioDataOutput()
    private let audioQueue = DispatchQueue(label:"edu.utah.cs.benjones.AudioBufferQueue")
    
    
    private let clock = CMClockGetHostTimeClock()
    private var recordingStartTime = CMTime()
    private(set) var recording = false
    //returns true if the recording actually started
    func startRecording(url : URL, audioDevice: AVCaptureDevice?, delegate: AVCaptureAudioDataOutputSampleBufferDelegate) -> Bool {
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let settingsAssistant = AVOutputSettingsAssistant(preset: .preset1920x1080)?.videoSettings
            assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settingsAssistant)
            assetWriterVideoInput?.expectsMediaDataInRealTime = true
            assetWriterVideoAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterVideoInput!, sourcePixelBufferAttributes: nil)
            assetWriter!.add(assetWriterVideoInput!)

            //audio setup
            if audioDevice != nil {
                avCaptureSession.beginConfiguration()
                avCaptureSession.addInput(try AVCaptureDeviceInput(device: audioDevice!))
                audioCaptureOutput.setSampleBufferDelegate(delegate, queue: audioQueue)
                avCaptureSession.addOutput(audioCaptureOutput)
                avCaptureSession.commitConfiguration()
                avCaptureSession.startRunning()
                

                
                let audioSettings = audioCaptureOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4)
                Logger().debug("recording audio settings: \(audioSettings!.debugDescription)")
                assetWriterAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                assetWriterAudioInput?.expectsMediaDataInRealTime = true
                assetWriter!.add(assetWriterAudioInput!)
                
                NotificationCenter.default.addObserver(forName: AVCaptureInput.Port.formatDescriptionDidChangeNotification, object: nil, queue: nil) { notification in
                    Logger().debug("format changed: \(notification)")
                    
                }
                
                NotificationCenter.default.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: nil, queue: nil) { notification in
                    Logger().debug("runtime error: \(notification)")
                    
                }

                
            }
            
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
        //TODO: mirror frames here, maybe?
        assert(recording)
        if assetWriterVideoInput!.isReadyForMoreMediaData {
            assetWriterVideoAdaptor!.append(frame, withPresentationTime: clock.time)
        } else {
            Logger().debug("not ready for more input data")
        }
    }
    
    func writeAudioSample(buffer: CMSampleBuffer){
        //Logger().debug("buffer: \(buffer.formatDescription.debugDescription)")
        if(assetWriterAudioInput != nil){
            if assetWriterAudioInput!.isReadyForMoreMediaData {
                assetWriterAudioInput!.append(buffer)
                
            } else {
                Logger().debug("audio writer not ready for sample")
            }
            powerMeter.process(buffer: buffer)
        }
    }
    
    func finishRecording(){
        assetWriterVideoInput!.markAsFinished()
        avCaptureSession.stopRunning()
        powerMeter.processSilence()
        if !avCaptureSession.inputs.isEmpty{
            avCaptureSession.removeInput(avCaptureSession.inputs.first!)
        }
        avCaptureSession.removeOutput(avCaptureSession.outputs.first!)
        assetWriter!.finishWriting {
            Logger().debug("finished writing video file!")
            self.recording = false
            self.assetWriter = nil
            self.assetWriterAudioInput = nil
        }
        
    }
}
