//
//  HoverOverlayView.swift
//  presenterMode
//
//  Created by Ben Jones on 10/6/26.
//

import SwiftUI

struct HoverOverlay<Content: View, Overlay: View>: View {
    let content: Content
    let overlay: Overlay

    @State private var isHovered = false

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.content = content()
        self.overlay = overlay()
    }

    var body: some View {
        content
            .overlay {
                if isHovered {
                    overlay
                }
            }
            .onHover { isHovered = $0 }
    }
}
