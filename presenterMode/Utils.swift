//
//  Utils.swift
//  presenterMode
//
//  Created by Ben Jones on 6/10/26.
//

import CoreGraphics
import AVFoundation
import OSLog


//from https://stackoverflow.com/questions/38318387/swift-cgimage-to-cvpixelbuffer
func pixelBufferFromCGImage(image: CGImage) -> CVPixelBuffer? {
    
    guard let imageData = image.dataProvider?.data,
        let mutableData = CFDataCreateMutableCopy(
            kCFAllocatorDefault,
            0,
            imageData
        ),
        let baseAddress = CFDataGetMutableBytePtr(mutableData)
    else {
        return nil
    }
    
    var pxbuffer: CVPixelBuffer? = nil
    let retainedData = Unmanaged.passRetained(mutableData)
    let releaseRefCon = retainedData.toOpaque()
    
    let releaseCallback: CVPixelBufferReleaseBytesCallback = { releaseRefCon, _ in
        guard let releaseRefCon else { return }
        Unmanaged<CFMutableData>.fromOpaque(releaseRefCon).release()
    }
    

    let width =  image.width
    let height = image.height
    let bytesPerRow = image.bytesPerRow


    let status = CVPixelBufferCreateWithBytes(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        baseAddress,
        bytesPerRow,
        releaseCallback,
        releaseRefCon,
        nil,
        &pxbuffer
    )
    if(status != kCVReturnSuccess){
        Logger().debug("cvpbcwb failed \(status)")
    }
    return pxbuffer
}

func rectsApproxEqual(_ r1: CGSize, _ r2: CGSize) -> Bool{
    return (abs(r1.width - r2.width) + abs(r1.height - r2.height)) < 5 //+/- ~ 2 pixels in each dimension seems fine
}
