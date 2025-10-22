import SwiftUI

struct LanguageMenuButton: View {
    @EnvironmentObject private var session: AppSession

    private let languages: [LanguageOption] = [
        .init(code: "he", label: "HE"),
        .init(code: "ar", label: "AR"),
        .init(code: "en", label: "EN"),
        .init(code: "ru", label: "RU")
    ]

    var body: some View {
        Menu {
            ForEach(languages) { language in
                Button {
                    Haptics.light()
                    withAnimation(DS.Animation.easeOut) {
                        session.languageCode = language.code
                    }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(language.label)
                            .font(DS.Font.body.weight(.medium))
                        if language.code == session.languageCode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "globe.asia.australia.fill")
                .imageScale(.medium)
                .padding(10)
                .background(
                    Circle()
                        .fill(DS.Color.surfaceElevated)
                        .shadow(color: DS.Color.brandPrimary.opacity(0.12), radius: 10, x: 0, y: 4)
                )
                .foregroundStyle(DS.Color.brandPrimary)
        }
        .menuIndicator(.hidden)
        .accessibilityLabel(Text(String(localized: "language_picker")))
    }
}

private struct LanguageOption: Identifiable {
    let code: String
    let label: String
    var id: String { code }
    var locale: Locale { Locale(identifier: code) }
}
