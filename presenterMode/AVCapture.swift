//
//  AVCapture.swift
//  presenterMode
//
//  Created by Ben Jones on 1/8/22.
//

import Foundation
import AVFoundation
import CoreMediaIO
import Combine
import SwiftUI
import OSLog

class AVDeviceManager : NSObject, ObservableObject {
    
    //video devices to mirror
    @Published var avCaptureDevices : [AVWrapper] = []
    //audio devices to record to video with
    @Published var avAudioDevices: [AVWrapper] = []
    private let avCaptureSession = AVCaptureSession()
    
    private let connectionPublisher = NotificationCenter.default
        .publisher(for: NSNotification.Name.AVCaptureDeviceWasConnected)
    private let disconnectionPublisher = NotificationCenter.default
        .publisher(for: NSNotification.Name.AVCaptureDeviceWasDisconnected)
    private var connectedSubscriptionHandle : AnyCancellable? = nil
    private var disconnectedSubscriptionHandle : AnyCancellable? = nil
    
    private var avOutput = AVCaptureVideoDataOutput()
    
    override init(){
        super.init()
        //without this ipads won't show up as capture dvices
        //From https://stackoverflow.com/questions/48646470/ios-device-not-listed-by-avcapturedevice-devices-unless-quicktime-is-opened
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        
        var allow : UInt32 = 1
        let dataSize : UInt32 = 4
        let zero : UInt32 = 0
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, zero, nil, dataSize, &allow)
        
        getCaptureDevices()
        
        connectedSubscriptionHandle = connectionPublisher.sink { (message) in
            let device : AVCaptureDevice = message.object as! AVCaptureDevice;
            Logger().debug("connected device: \(device.localizedName)")
            Task { @MainActor in
                if(device.deviceType == .microphone){
                    self.avAudioDevices.append(AVWrapper(dev : device))
                } else {
                    self.avCaptureDevices.append(AVWrapper(dev: device))
                }
            }
            
        }
        
        disconnectedSubscriptionHandle = disconnectionPublisher.sink { (message) in
            let device : AVCaptureDevice = message.object as! AVCaptureDevice;
            Task { @MainActor in
                self.avCaptureDevices.removeAll(where: { $0.device == device})
                self.avAudioDevices.removeAll(where: { $0.device == device})
            }
        }
    }
    
    private func getCaptureDevices() -> Void {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
                                                                            [.external, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
                Task { @MainActor in
                    self.avCaptureDevices = discoverySession.devices.map({device -> AVWrapper in
                        return AVWrapper(dev: device)
                    })
                    Logger().debug("capture devices from discovery session: \(self.avCaptureDevices)");
                }
            }
            
        }
        
        AVCaptureDevice.requestAccess(for: .audio){ granted in
            if granted {
                let discoverySession = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.microphone],
                    mediaType: .audio, position: .unspecified)
                Task { @MainActor in
                    self.avAudioDevices = discoverySession.devices.map({device -> AVWrapper in
                        return AVWrapper(dev: device)})
                    Logger().debug("audio devices from discovery session: \(self.avAudioDevices)");
                }
            }
        }
    }
    
    func setupCaptureSession(device: AVCaptureDevice, screenPickerManager: StreamManager){
        Logger().debug("setup capture session for \(device.localizedName)")
        
        avCaptureSession.beginConfiguration()
        
        do {
            removeAllInputsAndOutputs()
            try avCaptureSession.addInput(AVCaptureDeviceInput(device: device));
            avOutput.setSampleBufferDelegate(screenPickerManager.scDelegate, queue: screenPickerManager.videoSampleBufferQueue)
            if(!(avCaptureSession.canAddOutput(avOutput))){
                Logger().debug("Can't add output for some reason!")
            }
            avCaptureSession.addOutput(avOutput)
            Logger().debug("video settings \(self.avOutput.videoSettings)")
            avCaptureSession.commitConfiguration();
            avCaptureSession.startRunning();
        } catch {
            print("Error setting up cature session: \(error)")
        }
    }
    
    fileprivate func removeAllInputsAndOutputs() {
        let inputs = avCaptureSession.inputs
        for input in inputs {
            avCaptureSession.removeInput(input);
        }
        let outputs = avCaptureSession.outputs
        for output in outputs {
            avCaptureSession.removeOutput(output)
        }
    }
    
    func stopSharing(){
        if(avCaptureSession.isRunning){
            avCaptureSession.stopRunning()
            removeAllInputsAndOutputs()
            
        } else {
            Logger().debug("called av stopSharing when it wasn't running")
        }
    }
}

struct AVWrapper : Identifiable, Hashable {
    let device: AVCaptureDevice
    let id: ObjectIdentifier
    
    init(dev: AVCaptureDevice){
        device = dev
        id = ObjectIdentifier(device)
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

