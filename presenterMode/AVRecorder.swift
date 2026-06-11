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
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

            guard let videoSettings = AVOutputSettingsAssistant(preset: .preset1920x1080)?.videoSettings else {
                Logger().error("Could not create video output settings")
                return false
            }

            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true

            guard writer.canAdd(videoInput) else {
                Logger().error("Could not add video input to asset writer")
                return false
            }

            let videoAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: nil
            )

            writer.add(videoInput)

            //audio setup
            if let audioDevice {
                avCaptureSession.beginConfiguration()
                avCaptureSession.addInput(try AVCaptureDeviceInput(device: audioDevice))
                audioCaptureOutput.setSampleBufferDelegate(delegate, queue: audioQueue)
                avCaptureSession.addOutput(audioCaptureOutput)
                avCaptureSession.commitConfiguration()
                avCaptureSession.startRunning()
                

                
                let audioSettings = audioCaptureOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4)
                Logger().debug("recording audio settings: \(audioSettings!.debugDescription)")
                let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput.expectsMediaDataInRealTime = true
                writer.add(audioInput)
                assetWriterAudioInput = audioInput
                
                NotificationCenter.default.addObserver(forName: AVCaptureInput.Port.formatDescriptionDidChangeNotification, object: nil, queue: nil) { notification in
                    Logger().debug("format changed: \(notification)")
                    
                }
                
                NotificationCenter.default.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: nil, queue: nil) { notification in
                    Logger().debug("runtime error: \(notification)")
                }
            }
            
            writer.startWriting()
            recordingStartTime = clock.time
            writer.startSession(atSourceTime: recordingStartTime)
            
            assetWriter = writer
            assetWriterVideoInput = videoInput
            assetWriterVideoAdaptor = videoAdaptor
            
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
        
        guard recording else { return }
        recording = false

        audioCaptureOutput.setSampleBufferDelegate(nil, queue: nil)

        assetWriterVideoInput?.markAsFinished()
        assetWriterAudioInput?.markAsFinished()

        if avCaptureSession.isRunning {
            avCaptureSession.stopRunning()
        }

        for input in avCaptureSession.inputs {
            avCaptureSession.removeInput(input)
        }

        for output in avCaptureSession.outputs {
            avCaptureSession.removeOutput(output)
        }

        powerMeter.processSilence()

        assetWriter?.finishWriting { [weak self] in
            Logger().debug("finished writing video file!")
            self?.assetWriter = nil
            self?.assetWriterVideoInput = nil
            self?.assetWriterVideoAdaptor = nil
            self?.assetWriterAudioInput = nil
        }
        
    }
}
