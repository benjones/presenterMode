//
//  HistoryManager.swift
//  presenterMode
//
//  Created by Ben Jones on 6/10/26.
//

import CoreGraphics
import OSLog
import ScreenCaptureKit
import CollectionConcurrencyKit

struct HistoryEntry {
    let scWindow: SCWindow
    var preview: CGImage?
}

@MainActor
final class HistoryManager: ObservableObject {
    @Published private(set) var entries = [HistoryEntry]()

    private let logger = Logger()

    func update(filter: SCContentFilter) async {
        switch filter.style {
        case .window:
            let matchingWindows = await getCurrentlySharedWindows(size: filter.contentRect.size)
            let refreshedEntries = await matchingWindows.concurrentCompactMap { window in
                await self.makeHistoryEntry(for: window)
            }

            entries.removeAll { entry in
                matchingWindows.contains(entry.scWindow)
            }
            entries.append(contentsOf: refreshedEntries)
        case .none:
            logger.error("Filter has no style (type)")
        case .display:
            logger.debug("sharing a full display, not adding to history")
        case .application:
            logger.debug("sharing an application, not adding to history")
        @unknown default:
            logger.error("Filter has unknown style (type)")
        }
    }

    private func makeHistoryEntry(for window: SCWindow) async -> HistoryEntry? {
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.scalesToFit = true

        do {
            let screenshot = try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: window),
                configuration: config
            )
            return HistoryEntry(scWindow: window, preview: screenshot)
        } catch {
            logger.debug("history entry add failed: \(error)")
            return nil
        }
    }

    private func getCurrentlySharedWindows(size: CGSize) async -> [SCWindow] {
        do {
            let allContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let allWindows = allContent.windows
            return allWindows.filter { window in
                window.isActive && window.frame.size == size
            }
        } catch {
            logger.debug("failed figuring out what the old window was: \(error)")
            return []
        }
    }
}
