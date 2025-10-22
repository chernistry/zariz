import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    init(title: String, subtitle: String? = nil, systemImage: String = "tray") {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }
        .multilineTextAlignment(.center)
        .padding(DS.Spacing.xl)
    }
}

