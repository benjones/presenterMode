//
//  ContentView.swift
//  presenterView
//
//  Created by Ben Jones on 9/17/21.
//

import SwiftUI

struct ContentView: View {
    @State private var windowPreviews : [WindowPreview] = []
    
    
    
    var body: some View {
        VStack {
            Text("Presenter View")
                .font(.title)
                .padding()
            
            Text("Select Window to Share")
                .font(.subheadline)
                .padding()
            
            Button(action: refreshWindows) {
                Text("Refresh Windows")
                    .font(.subheadline)
            }
            
            ScrollView{
                LazyVGrid(columns: Array(repeating: GridItem.init(.fixed(300)), count: 4)){
                    ForEach(windowPreviews) { windowPreview in
                        VStack {
                            Image(windowPreview.image, scale: 1.0, orientation: Image.Orientation.up, label: Text(windowPreview.title))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 300, height: 300, alignment: .center)
                                .border(Color.white)
                            Text("\(windowPreview.owner): \(windowPreview.title)")
                        }
                    }
                }.onAppear(perform: refreshWindows)
            }
        }
    }
    
    func refreshWindows() -> Void {
        windowPreviews = getWindowPreviews()
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
