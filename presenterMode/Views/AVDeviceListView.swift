//
//  AVDeviceListView.swift
//  presenterMode
//
//  Created by Ben Jones on 10/24/24.
//

import SwiftUI

struct AVDeviceListView : View {
    
    let captureDevices: [AVWrapper]
    let deviceCallback: (AVWrapper) -> Void
    
    var body : some View {
        ScrollView{
            VStack{
                Text("Devices")
                    .font(.title)
                ForEach(captureDevices, id: \.id) {avWrapper in
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
