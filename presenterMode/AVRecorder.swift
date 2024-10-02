//
//  AVRecorder.swift
//  presenterMode
//
//  Created by Ben Jones on 9/30/24.
//

import Foundation
import AVFoundation

class AVStreamDelegate : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ){
        
    }
}
