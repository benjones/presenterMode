//
//  HistoryView.swift
//  presenterMode
//
//  Created by Ben Jones on 10/25/24.
//

import SwiftUI

struct HistoryView : View {
    
    let entries: [HistoryEntry]
    let historyCallback: (HistoryEntry)->Void
    
    var body: some View {
        
        ScrollView{
            //list of window history
            VStack(alignment: .center){
                Text("Screen History")
                    .frame(idealWidth:320)
                    .font(.title)
                
                ForEach(entries,
                        id: \.self.scWindow.windowID){ historyEntry in
                    HistoryEntryView(
                        windowTitle: historyEntry.scWindow.title,
                        previewImage: historyEntry.preview)
                    .onTapGesture {
                        historyCallback(historyEntry)
                    }
                }
            }.frame(minWidth:340)
        }
    }
}
