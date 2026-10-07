//
//  Utils.swift
//  presenterMode
//
//  Created by Ben Jones on 6/10/26.
//

import CoreGraphics
import AVFoundation
import OSLog
import ScreenCaptureKit


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

func getScreenshot(for window: SCWindow) async throws -> CGImage{
    let config = SCStreamConfiguration()
    config.width = Int(window.frame.width)
    config.height = Int(window.frame.height)
    config.scalesToFit = true
    return try await SCScreenshotManager.captureImage(
        contentFilter: SCContentFilter(desktopIndependentWindow: window),
        configuration: config
    )
}

func findDisplay(containing window: SCWindow) async throws -> SCDisplay? {
    let content = try await SCShareableContent.excludingDesktopWindows(
        false,
        onScreenWindowsOnly: true
    )
    
    let windowCenter = CGPoint(
        x: window.frame.midX,
        y: window.frame.midY
    )
    
    return content.displays.first {
        $0.frame.contains(windowCenter)
    }
}

func getAllWindows() async -> [SCWindow] {
    do {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        return availableContent.windows

//        Logger().debug("num windows: \(windows.count)")
//        return await windows.asyncCompactMap{ window in
//            guard !window.frame.isEmpty else {
//                return nil
//            }
//            do {
//                return try await getScreenshot(for: window)
//            } catch {
//                //Logger().debug("Failed to get screenshot: \(error) \(window.description)")
//                return nil
//            }
//        }
        

    } catch {
        Logger().debug("Couldn't get windows: \(error)")
        return []
    }

}
