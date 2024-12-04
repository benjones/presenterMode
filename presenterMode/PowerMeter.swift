
/*
 
 This code from the screen capture kit sample from here: https://developer.apple.com/documentation/screencapturekit/capturing_screen_content_in_macos
 
 
 
 Copyright © 2023 Apple Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 
 //This is probably way overkill for what I'm doing...
 
 Abstract:
 An object that calculates the average and peak power levels for the captured audio samples.
 */

import Foundation
import AVFoundation
import Accelerate

struct AudioLevels {
    static let zero = AudioLevels(level: 0, peakLevel: 0)
    let level: Float
    let peakLevel: Float
}

// The protocol for the object that provides peak and average power levels to adopt.
protocol AudioLevelProvider {
    var levels: AudioLevels { get }
}

class PowerMeter: AudioLevelProvider {
    private let kMinLevel: Float = 0.000_000_01 // -160 dB
    
    private struct PowerLevels {
        let average: Float
        let peak: Float
    }
    
    private var values = [PowerLevels]()
    
    private var meterTableAverage = MeterTable()
    private var meterTablePeak = MeterTable()
    
    var levels: AudioLevels {
        if values.isEmpty { return AudioLevels(level: 0.0, peakLevel: 0.0) }
        return AudioLevels(level: meterTableAverage.valueForPower(values[0].average),
                           peakLevel: meterTablePeak.valueForPower(values[0].peak))
    }
    
    func processSilence() {
        if values.isEmpty { return }
        values = []
    }
    
    //modified from apple version to use CMSampleBuffer instead of AVAudioPCMBuffer
    // Calculates the average (rms) and peak level of each channel in the PCM buffer and caches data.
    func process(buffer: CMSampleBuffer) {
        assert(buffer.formatDescription?.mediaType == .audio)
        
        var powerLevels = [PowerLevels]()
        
        var audioBufferList = AudioBufferList()
        var blockBuffer : CMBlockBuffer?
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(buffer,
                                                                bufferListSizeNeededOut: nil,
                                                                bufferListOut: &audioBufferList,
                                                                bufferListSize: MemoryLayout<AudioBufferList>.size,
                                                                blockBufferAllocator: nil,
                                                                blockBufferMemoryAllocator: nil,
                                                                flags: 0,
                                                                blockBufferOut: &blockBuffer)
        
        
        //TODO use with unsafe pointer here
        //the unsafe mutable type lets you actually iterate through them
        withUnsafeMutablePointer(to: &audioBufferList){ bufferListPtr in
            let audioBufferListPtr = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferListPtr))
            let formatFlags = buffer.formatDescription!.audioStreamBasicDescription?.mFormatFlags
            let bitsPerSample = buffer.formatDescription!.audioStreamBasicDescription?.mBitsPerChannel
            let floatArrays = audioBufferListPtr.map{ buffer in
                
                //this is the format I get from the internal microphone
                if((formatFlags! & 1) != 0){//should be 32 bit floats
                    assert(bitsPerSample == 32)
                    //don't care how many channels it is, just get all the samples
                    let floatPtr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    let floatBuffer = UnsafeBufferPointer<Float>(start: floatPtr, count: Int(buffer.mDataByteSize)/MemoryLayout<Float>.size)
                    return Array(floatBuffer)
                } else if(((formatFlags! & kAudioFormatFlagIsPacked) != 0) && ((formatFlags! & kAudioFormatFlagIsSignedInteger) != 0)){
                    // my pixel buds pro give me format 12 which is
                    // packed | signed integer, 16 bits per sample
                    
                    if(bitsPerSample == 16){
                        let shortPtr = buffer.mData!.assumingMemoryBound(to: Int16.self)
                        let shortBuffer = UnsafeBufferPointer<Int16>(start: shortPtr, count: Int(buffer.mDataByteSize)/MemoryLayout<Int16>.size)
                        return shortBuffer.map{ i16 in Float(i16)/Float(Int16.max)}
                    } //TODO: check for 32 BPS?
                    
                }
                //TODO, just ignore this?
                //assert(false, "Unknown audio format!")
                return [Float]()
                
                
            }
            
            floatArrays.forEach{floats in
                powerLevels.append(calculatePowers(data: floats))
            }
            self.values = powerLevels
        }
//        
//
//        var data  =  audioBufferList.mBuffers.mData
//        
//        let pointer = data?.assumingMemoryBound(to: Float.self)
//        assert(buffer.formatDescription?.audioStreamBasicDescription.)
//        let i16Samples = data?.bindMemory(to: Int16.self, capacity: 1024)
//        
//        let floatBuffer = UnsafeBufferPointer(start: floatPointer, count: 1024)
//        let outputArray = Array(floatBuffer)
//        
//        
//        
//        let channelCount = Int(buffer.format.channelCount)
//        let length = vDSP_Length(buffer.frameLength)
//        
//        if let floatData = buffer.floatChannelData {
//            for channel in 0..<channelCount {
//                
//            }
//        } else if let int16Data = buffer.int16ChannelData {
//            for channel in 0..<channelCount {
//                // Convert the data from int16 to float values before calculating the power values.
//                var floatChannelData: [Float] = Array(repeating: Float(0.0), count: Int(buffer.frameLength))
//                vDSP_vflt16(int16Data[channel], buffer.stride, &floatChannelData, buffer.stride, length)
//                var scalar = Float(INT16_MAX)
//                vDSP_vsdiv(floatChannelData, buffer.stride, &scalar, &floatChannelData, buffer.stride, length)
//                
//                powerLevels.append(calculatePowers(data: floatChannelData, strideFrames: buffer.stride, length: length))
//            }
//        } else if let int32Data = buffer.int32ChannelData {
//            for channel in 0..<channelCount {
//                // Convert the data from int32 to float values before calculating the power values.
//                var floatChannelData: [Float] = Array(repeating: Float(0.0), count: Int(buffer.frameLength))
//                vDSP_vflt32(int32Data[channel], buffer.stride, &floatChannelData, buffer.stride, length)
//                var scalar = Float(INT32_MAX)
//                vDSP_vsdiv(floatChannelData, buffer.stride, &scalar, &floatChannelData, buffer.stride, length)
//                
//                powerLevels.append(calculatePowers(data: floatChannelData, strideFrames: buffer.stride, length: length))
//            }
//        }
//        self.values = powerLevels
    }
    
    private func calculatePowers(data: [Float]) -> PowerLevels {
        //vDSP_maxv(data, strideFrames, &max, length)
        var max = vDSP.maximum(data)
        if max < kMinLevel {
            max = kMinLevel
        }
        
        var rms = vDSP.rootMeanSquare(data)
        if rms < kMinLevel {
            rms = kMinLevel
        }
        
        return PowerLevels(average: 20.0 * log10(rms), peak: 20.0 * log10(max))
    }
}

private struct MeterTable {
    
    // The decibel value of the minimum displayed amplitude.
    private let kMinDB: Float = -60.0
    
    // The table needs to be large enough so that there are no large gaps in the response.
    private let tableSize = 300
    
    private let scaleFactor: Float
    private var meterTable = [Float]()
    
    init() {
        let dbResolution = kMinDB / Float(tableSize - 1)
        scaleFactor = 1.0 / dbResolution
        
        // This controls the curvature of the response.
        // 2.0 is the square root, 3.0 is the cube root.
        let root: Float = 2.0
        
        let rroot = 1.0 / root
        let minAmp = dbToAmp(dBValue: kMinDB)
        let ampRange = 1.0 - minAmp
        let invAmpRange = 1.0 / ampRange
        
        for index in 0..<tableSize {
            let decibels = Float(index) * dbResolution
            let amp = dbToAmp(dBValue: decibels)
            let adjAmp = (amp - minAmp) * invAmpRange
            meterTable.append(powf(adjAmp, rroot))
        }
    }
    
    private func dbToAmp(dBValue: Float) -> Float {
        return powf(10.0, 0.05 * dBValue)
    }
    
    func valueForPower(_ power: Float) -> Float {
        if power < kMinDB {
            return 0.0
        } else if power >= 0.0 {
            return 1.0
        } else {
            let index = Int(power) * Int(scaleFactor)
            return if index >= 0 && index < meterTable.count{ meterTable[index] } else { 0 }
        }
    }
}
