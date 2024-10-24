//
//  AVDeviceListView.swift
//  presenterMode
//
//  Created by Ben Jones on 10/24/24.
//

import SwiftUI

struct AVDeviceListView : View {
    
    @EnvironmentObject var avDeviceManager : AVDeviceManager
    let deviceCallback: (AVWrapper) -> Void
    
    var body : some View {
        ScrollView{
            VStack{
                Text("Devices")
                    .font(.title)
                ForEach(avDeviceManager.avCaptureDevices, id: \.id) {avWrapper in
                    VStack {
                        Text("\(maybeTruncate( str: avWrapper.device.localizedName))")
                            .frame(width: 320, height: 60)
                            .background(Color.secondary)
                            .border(Color.accentColor)
                    }.onTapGesture {
                        deviceCallback(avWrapper)
                    }
                }
            }.frame(minWidth:340)
        }
    }
}
