//
//  HistoryView.swift
//  presenterMode
//
//  Created by Ben Jones on 10/25/24.
//

import SwiftUI

struct HistoryView<Entries: RandomAccessCollection> : View where Entries.Element == HistoryEntry {
    
    let entries: Entries
    let historyCallback: (HistoryEntry) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 12) {
                Text("Window History")
                    .font(.title2)

                ForEach(entries, id: \.scWindow.windowID) { historyEntry in
                    HistoryEntryView(
                        windowTitle: historyEntry.scWindow.title,
                        previewImage: historyEntry.preview
                    )
                    .onTapGesture {
                        historyCallback(historyEntry)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 4)
        }
    }
}
