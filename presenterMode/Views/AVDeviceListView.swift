//
//  AVDeviceListView.swift
//  presenterMode
//
//  Created by Ben Jones on 10/24/24.
//

import SwiftUI

struct AVDeviceListView : View {
    
    let captureDevices: [AVWrapper]
    let deviceCallback: (AVWrapper) -> Void

    private func iconName(for deviceName: String) -> String? {
        let name = deviceName.lowercased()

        if name.contains("camera") {
            return "video.fill"
        } else if name.contains("ipad") {
            return "ipad"
        } else {
            return nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Devices")
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(captureDevices, id: \.id) { avWrapper in
                    Button {
                        deviceCallback(avWrapper)
                    } label: {
                        HStack(spacing: 8) {
                            Group {
                                if let iconName = iconName(for: avWrapper.device.localizedName) {
                                    Image(systemName: iconName)
                                }
                            }
                            .frame(width: 18)

                            Text(avWrapper.device.localizedName)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .background(
                            Color.accentColor.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.65), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
