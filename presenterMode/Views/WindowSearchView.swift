//
//  WindowSearchView.swift
//  presenterMode
//
//  Created by Ben Jones on 9/30/26.
//

import SwiftUI
import OSLog
import ScreenCaptureKit
import FuzzyMatch
import Algorithms

struct SearchResultData : Hashable {
    var window: SCWindow
    var preview: CGImage
}

struct WindowSearchView : View {
    
    @State private var windowTitles: [String] = ["Hello", "World"]
    @State private var showResults = false;
    @State private var searchText = ""
    @State private var windowPreviews = [SearchResultData]()
    @FocusState private var searchFocused: Bool;
    @Environment(\.isSearching) private var isSearching
    
    
    var body : some View {
        TextField("Search", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .focused($searchFocused)
            .onChange(of: searchFocused) { _, focused in
                if focused {
                    showResults = true
                    
                }
            }
            .task(id: searchText){
                guard !searchText.isEmpty else {
                    windowPreviews = []
                    showResults = false
                    return
                }
                do {
                    try await Task.sleep(for: .milliseconds(250)) // debounce
                    guard !Task.isCancelled else { return }
                    Logger().debug("Getting window previews")
                    
                    //filter icons and dock and other stuff
                    let scwindows = await getAllWindows().filter{ scw in
                        return scw.title != nil &&  scw.frame.width > 100 && scw.frame.height > 100
                    }
                    Logger().debug("Num scwindows: \(scwindows.count)")
                    
                    let matcher = FuzzyMatcher()
                    let query = matcher.prepare(searchText)
                    var buffer = matcher.makeBuffer()
                    let numMatches = 16 //give us a nice 4x4 grid below
                    
                    func scoreWindow(_ scw: SCWindow, query: FuzzyQuery, buffer: inout ScoringBuffer) -> Double {
                        guard let title = scw.title else { return 0}
                        return matcher.score(title, against: query, buffer: &buffer)?.score ?? 0
                    }
                    
                    //filter the trash
                    let bestMatches = scwindows.min(count: numMatches){ sc0, sc1 in
                        scoreWindow(sc0, query: query, buffer: &buffer) > scoreWindow(sc1, query: query, buffer: &buffer)
                    }.filter{ sc in
                        scoreWindow(sc, query: query, buffer: &buffer) >= 0.5
                    }

                
                    
                    windowPreviews = await bestMatches.asyncCompactMap{ window  in
                        guard !window.frame.isEmpty else {
                            return nil
                        }
                        do {
                            let screenshot = try await getScreenshot(for: window)
                            return SearchResultData(window: window, preview: screenshot)
                        } catch {
                            Logger().debug("Failed to get screenshot: \(error) \(window.description)")
                            return nil
                        }
                    }
                    
                    Logger().debug("got windows, length: \(windowPreviews.count)")
                    bestMatches.forEach { match in
                        Logger().debug("match: \(match.title!) score: \(scoreWindow(match, query: query, buffer: &buffer))")
                    }
                    showResults = true
                } catch is CancellationError {
                    // Expected while the user continues typing.
                } catch {
                    Logger().debug("Task error: \(error)")
                }
                
            }

            .popover(isPresented: $showResults, arrowEdge: .bottom) {
                Text("Search results! \(searchText)")
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(220)), count: 4)) {
                    ForEach(windowPreviews, id: \.self) { window in
                        VStack {
                            Image(decorative: window.preview, scale: 1.0)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                            Text(window.window.title!)
                        }
                        .padding(16)
                    }
                }
            }
    }
}
        
        
        //        NavigationStack{
        //            Text("Search For Windows")
        //                .searchable(text: $searchText)
        //                .onChange(of: isSearching) { _, active in
        //                    if active { showResults = true }
        //                }
        //                .popover(isPresented: $showResults, arrowEdge: .top) {
        //                    Text("Search results! \(searchText)")
        //                }
        //        }
