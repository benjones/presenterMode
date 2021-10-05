//
//  MirrorView.swift
//  presenterView
//
//  Created by Ben Jones on 10/1/21.
//

import SwiftUI

struct MirrorView: View {
    @EnvironmentObject var globalViewModel : GlobalViewModel
    
    var body: some View {
        Group(){
            Image(globalViewModel.image, scale: 1.0, orientation: Image.Orientation.up, label: Text(""))
                .resizable()
                .aspectRatio(contentMode: .fit)
            
        }.frame(minWidth: 960, idealWidth: 1280, maxWidth: CGFloat.infinity, minHeight: 540, idealHeight: 720,  maxHeight: CGFloat.infinity)
            
                
    }
}
    
    
            

struct MirrorView_Previews: PreviewProvider {
    static var previews: some View {
        MirrorView()
    }
}
