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
                assetWriterAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                assetWriter!.add(assetWriterAudioInput!)

                
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
        assert(recording)
        if assetWriterVideoInput!.isReadyForMoreMediaData {
            assetWriterVideoAdaptor!.append(frame, withPresentationTime: clock.time)
        } else {
            Logger().debug("not ready for more input data")
        }
    }
    
    func writeAudioSample(buffer: CMSampleBuffer){
        if(assetWriterAudioInput != nil){
            if assetWriterAudioInput!.isReadyForMoreMediaData {
                assetWriterAudioInput!.append(buffer)
            } else {
                Logger().debug("audio writer not ready for sample")
            }
        }
    }
    
    func finishRecording(){
        assetWriterVideoInput!.markAsFinished()
        avCaptureSession.stopRunning()
        avCaptureSession.removeInput(avCaptureSession.inputs.first!)
        avCaptureSession.removeOutput(avCaptureSession.outputs.first!)
        assetWriter!.finishWriting {
            Logger().debug("finished writing video file!")
            self.recording = false
            self.assetWriter = nil
            self.assetWriterAudioInput = nil
        }
        
    }
}
