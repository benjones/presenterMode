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

class AVDeviceManager : NSObject, ObservableObject {
    
    @Published var avCaptureDevices : [AVWrapper] = []
    @Published var avCaptureSession : AVCaptureSession?
    private var delegates : [DevicePhotoDelegate] = []
    
    
    private let connectionPublisher = NotificationCenter.default
        .publisher(for: NSNotification.Name.AVCaptureDeviceWasConnected)
    private var subscriptionHandle : AnyCancellable? = nil
    //let disconnectionPublisher = NotificationCenter.default
    //        .publisher(for: NSNotification.Name.AVCaptureDeviceWasDisconnected)
    
    override init(){
        super.init()
        //without this ipads won't show up as capture dvices
        //From https://stackoverflow.com/questions/48646470/ios-device-not-listed-by-avcapturedevice-devices-unless-quicktime-is-opened
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster))
        
        var allow : UInt32 = 1
        let dataSize : UInt32 = 4
        let zero : UInt32 = 0
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, zero, nil, dataSize, &allow)
        
        getCaptureDevices()
        
        subscriptionHandle = connectionPublisher.sink { (message) in
            print("got a message from the connection publisher")
            let device : AVCaptureDevice = message.object as! AVCaptureDevice;
            print(device.deviceType, " localized name: ", device.localizedName, " model id", device.modelID)
            self.avCaptureDevices.append(AVWrapper(dev: device))
            //            var session = AVCaptureSession();
            //
            //            let photoOutput = AVCapturePhotoOutput()
            //
            //            session.beginConfiguration()
            //
            //            guard session.canAddOutput(photoOutput) else { return }
            //            session.sessionPreset = .photo
            //            session.addOutput(photoOutput)
            //            print("output added to session")
            //            do {
            //                try session.addInput(AVCaptureDeviceInput(device: device));
            //                print("input added to session")
            //                session.commitConfiguration();
            //                session.startRunning();
            //                print("session running")
            //
            //                let photoSettings = AVCapturePhotoSettings()
            //
            //
            //                print("about to try to capture a photo with",  device.localizedName)
            //
            //                let del = DevicePhotoDelegate(dev: device, man: self)
            //                self.delegates.append(del)
            //                photoOutput.capturePhoto(with: photoSettings, delegate: del)
            //
            //            } catch {
            //                print("couldn't add capture device as input")
            //            }
        }
    }
    
    
    
    func getCaptureDevices() -> Void {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
                                                                            [.externalUnknown, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
                self.avCaptureDevices = discoverySession.devices.map({device -> AVWrapper in
                    return AVWrapper(dev: device)
                })
            }
            print(self.avCaptureDevices);
        }
    }
    
    func setupCaptureSession(device: AVCaptureDevice) -> Bool{
        avCaptureSession = AVCaptureSession();
        
        avCaptureSession!.beginConfiguration()
        
        do {
            try avCaptureSession!.addInput(AVCaptureDeviceInput(device: device));
            print("input added to session")
            avCaptureSession!.commitConfiguration();
            avCaptureSession!.startRunning();
            return true
        } catch {
            print("Error setting up cature session: \(error)")
            return false
        }
    }
    
    func stopSharing(){
        print("TODO stop sharing")
    }
}

struct AVWrapper : Identifiable {
    
    
    let device: AVCaptureDevice
    //let imagePreview :CGImage
    
    let id: ObjectIdentifier
    init(dev: AVCaptureDevice){
        device = dev
        //imagePreview = im
        id = ObjectIdentifier(device)
    }
}

class DevicePhotoDelegate : NSObject, AVCapturePhotoCaptureDelegate {
    let device : AVCaptureDevice
    let manager : AVDeviceManager
    
    init(dev : AVCaptureDevice, man : AVDeviceManager){
        device = dev
        manager = man
    }
    
    @objc(captureOutput:didFinishProcessingPhoto:error:) func photoOutput(_ output: AVCapturePhotoOutput,
                                                                          didFinishProcessingPhoto photo: AVCapturePhoto,
                                                                          error: Error?){
        print("got the ipad photo!")
        if (error != nil) {
            print("Error: ", error)
        }
        //manager.avWrappers.append(AVWrapper(dev: device,
        //                                            im: photo.cgImageRepresentation()!))
        
    }
    
    func photoOutput(_: AVCapturePhotoOutput, willBeginCaptureFor: AVCaptureResolvedPhotoSettings){
        print("will begin capture")
    }
    
    func photoOutput(_: AVCapturePhotoOutput, willCapturePhotoFor: AVCaptureResolvedPhotoSettings){
        print("will capture photo")
    }
    func photoOutput(_: AVCapturePhotoOutput, didFinishCaptureFor: AVCaptureResolvedPhotoSettings, error: Error?){
        print("capture complete")
        if (error != nil) {
            print("Error: ", error)
        }
        
    }
    
    
}


//adapted from from https://benoitpasquier.com/webcam-utility-app-macos-swiftui/
final class PlayerContainerView: NSViewRepresentable {
    typealias NSViewType = PlayerView
    
    let captureSession: AVCaptureSession
    
    init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
    }
    
    func makeNSView(context: Context) -> PlayerView {
        return PlayerView(captureSession: captureSession)
    }
    
    func updateNSView(_ nsView: PlayerView, context: Context) { }
}

class PlayerView: NSView {
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    init(captureSession: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        super.init(frame: .zero)
        
        setupLayer()
    }
    
    func setupLayer() {
        
        previewLayer?.frame = self.frame
        previewLayer?.contentsGravity = .resizeAspectFill
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.connection?.automaticallyAdjustsVideoMirroring = false
        
        layer = previewLayer
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
