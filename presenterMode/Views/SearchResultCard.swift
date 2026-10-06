import SwiftUI
import OSLog

struct SearchResultCard: View {
    let result: SearchResultData
    let onSwitch: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HoverOverlay {
            VStack {
                Image(decorative: result.preview, scale: 1.0)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)

                Text(result.window.title ?? "")
            }
        } overlay: {
            HStack {
                Button(action: onSwitch) {
                    Text("Switch")
                }

                Button(action: onAdd) {
                    Text("Add")
                }
            }
            .padding(8)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.25))
                }
            }
            .padding(16)
        }
        .padding(16)
    }
}
