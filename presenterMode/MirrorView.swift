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
    
    
    
    //@Binding var screenRecorder: ScreenRecorder
    
    var body: some View {
        Group(){
            switch globalViewModel.mirrorStatus {
            case .notSharing:
                Image(GlobalViewModel.staticImage, scale: 1.0, orientation: Image.Orientation.up, label: Text(""))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .windowShare:
                Text("todo")
                //screenRecorder.capturePreview
//                Image(globalViewModel.sharedWindowData.image , scale: 1.0, orientation: Image.Orientation.up, label: Text(""))
                    //.resizable()
                    //.aspectRatio(contentMode: .fit)
                
            case .sharedAVData:
                PlayerContainerView(captureSession: avDeviceManager.avCaptureSession!)
                
            }
            
        }.frame(minWidth: 960, idealWidth: 1280, maxWidth: CGFloat.infinity, minHeight: 540, idealHeight: 720,  maxHeight: CGFloat.infinity)
            .navigationTitle($globalViewModel.title)
    }
    
}


//struct MirrorView_Previews: PreviewProvider {
//    static var previews: some View {
//        MirrorView()
//    }
//}
