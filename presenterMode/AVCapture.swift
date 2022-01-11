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
    
    private let connectionPublisher = NotificationCenter.default
        .publisher(for: NSNotification.Name.AVCaptureDeviceWasConnected)
    private let disconnectionPublisher = NotificationCenter.default
        .publisher(for: NSNotification.Name.AVCaptureDeviceWasDisconnected)
    private var connectedSubscriptionHandle : AnyCancellable? = nil
    private var disconnectedSubscriptionHandle : AnyCancellable? = nil
    
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
        
        connectedSubscriptionHandle = connectionPublisher.sink { (message) in
            let device : AVCaptureDevice = message.object as! AVCaptureDevice;
            self.avCaptureDevices.append(AVWrapper(dev: device))
           
        }
        
        disconnectedSubscriptionHandle = disconnectionPublisher.sink { (message) in
            let device : AVCaptureDevice = message.object as! AVCaptureDevice;
            self.avCaptureDevices.removeAll(where: { $0.device == device})
           
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
        if avCaptureSession == nil {
            avCaptureSession = AVCaptureSession();
        }
        
        avCaptureSession = avCaptureSession //trigger the publisher?
        avCaptureSession!.beginConfiguration()
        
        do {
            try avCaptureSession!.addInput(AVCaptureDeviceInput(device: device));
            avCaptureSession!.commitConfiguration();
            avCaptureSession!.startRunning();

            return true
        } catch {
            print("Error setting up cature session: \(error)")
            return false
        }
    }
    
    func stopSharing(){
        if avCaptureSession != nil{
            avCaptureSession!.stopRunning()
            for input in avCaptureSession!.inputs {
                avCaptureSession!.removeInput(input);
            }
        }
    }
}

struct AVWrapper : Identifiable {
    let device: AVCaptureDevice
    let id: ObjectIdentifier
    
    init(dev: AVCaptureDevice){
        device = dev
        id = ObjectIdentifier(device)
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
