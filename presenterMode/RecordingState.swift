//
//  RecordingState.swift
//  presenterMode
//
//  Created by Ben Jones on 6/11/26.
//

import Foundation

@MainActor
final class RecordingState: ObservableObject {
    @Published var recording = false
    @Published var audioLevel: Float = 0
}
