//
//  HistoryView.swift
//  presenterMode
//
//  Created by Ben Jones on 10/25/24.
//

import SwiftUI

struct HistoryView<Entries: RandomAccessCollection> : View where Entries.Element == HistoryEntry {
    
    let entries: Entries
    let launchWindowPicker: () -> Void
    let historyCallback: (HistoryEntry)->Void

    
    var body: some View {
        
        ScrollView{
            //list of window history
            VStack(alignment: .center){
                Text("Screen History")
                    .frame(idealWidth:320)
                    .font(.title)
                
                Text("Launch Window Picker")
                    .frame(width: 320, height: 60)
                    .background(Color.secondary)
                    .border(Color.accentColor)
                    .onTapGesture {
                        launchWindowPicker()
                    }
                
                ForEach(entries,
                        id: \.scWindow.windowID){ historyEntry in
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
