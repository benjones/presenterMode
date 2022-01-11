//
//  MirrorView.swift
//  presenterView
//
//  Created by Ben Jones on 10/1/21.
//

import SwiftUI

struct MirrorView: View {
    @EnvironmentObject var globalViewModel : GlobalViewModel
    @EnvironmentObject var avDeviceManager: AVDeviceManager
    
    var body: some View {
        Group(){
            switch globalViewModel.mirrorStatus {
            case .notSharing:
                Image(GlobalViewModel.staticImage, scale: 1.0, orientation: Image.Orientation.up, label: Text(""))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .windowShare:
                Image(globalViewModel.sharedWindowData.image as! CGImage, scale: 1.0, orientation: Image.Orientation.up, label: Text(""))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
            case .sharedAVData:
                PlayerContainerView(captureSession: avDeviceManager.avCaptureSession!)
                
            }
            
        }.frame(minWidth: 960, idealWidth: 1280, maxWidth: CGFloat.infinity, minHeight: 540, idealHeight: 720,  maxHeight: CGFloat.infinity)
    }
    
}


struct MirrorView_Previews: PreviewProvider {
    static var previews: some View {
        MirrorView()
    }
}
