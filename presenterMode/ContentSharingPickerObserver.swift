//
//  ContentSharingPickerObserver.swift
//  presenterMode
//
//  Created by Ben Jones on 6/11/26.
//

import Foundation
import ScreenCaptureKit

final class ContentSharingPickerObserver: NSObject, SCContentSharingPickerObserver {
    private let didUpdate: @MainActor (SCContentFilter, SCStream?) -> Void
    private let didFail: @MainActor (any Error) -> Void

    init(
        didUpdate: @escaping @MainActor (SCContentFilter, SCStream?) -> Void,
        didFail: @escaping @MainActor (any Error) -> Void
    ) {
        self.didUpdate = didUpdate
        self.didFail = didFail
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        // User cancelled while selecting content.
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
            didUpdate(filter, stream)
        }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in
            didFail(error)
        }
    }
}
