import SwiftUI

struct GlobalNavToolbar: ViewModifier {
    @EnvironmentObject private var session: AppSession
    var showLogout: Bool = true

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    LanguageMenuButton()
                        .buttonStyle(.plain)
                    if showLogout {
                        Button {
                            Haptics.light()
                            KeychainTokenStore.clear()
                            session.isAuthenticated = false
                            session.isDemoMode = false
                        } label: {
                            Label(String(localized: "logout"), systemImage: "rectangle.portrait.and.arrow.right")
                                .labelStyle(.iconOnly)
                                .imageScale(.medium)
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(DS.Color.surfaceElevated)
                                        .shadow(color: DS.Color.brandPrimary.opacity(0.12), radius: 10, x: 0, y: 4)
                                )
                                .foregroundStyle(DS.Color.brandPrimary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(String(localized: "logout")))
                    }
                }
            }
    }
}

extension View {
    func globalNavToolbar(showLogout: Bool = true) -> some View {
        modifier(GlobalNavToolbar(showLogout: showLogout))
    }
}
