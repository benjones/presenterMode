//
//  HistoryEntryView.swift
//  presenterMode
//
//  Created by Ben Jones on 10/23/24.
//

import SwiftUI

struct HistoryEntryView : View {
    
    var windowTitle: String?
    var previewImage: CGImage?
    
    var body: some View {
        VStack {
            if(previewImage != nil){
                Image(previewImage!, scale: 1.0, orientation: Image.Orientation.up, label: Text("label"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 320, height: 180, alignment: .center)
                    .border(Color.white)
            }
            Text("Title: \(windowTitle ?? "Untitled")")
        }
    }
}
