import SwiftUI

struct GlobalNavToolbar: ViewModifier {
    @EnvironmentObject private var session: AppSession
    @State private var showLanguageDialog = false
    var showHomeInDemo: Bool = true
    var showLogout: Bool = true

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showLanguageDialog = true }) {
                        Image(systemName: "globe")
                    }
                    if showLogout {
                        Button(String(localized: "logout")) {
                            KeychainTokenStore.clear()
                            session.isAuthenticated = false
                            session.isDemoMode = false
                        }
                    }
                }
            }
            .confirmationDialog(String(localized: "choose_language"), isPresented: $showLanguageDialog, titleVisibility: .visible) {
                Button("HE") { session.languageCode = "he" }
                Button("AR") { session.languageCode = "ar" }
                Button("EN") { session.languageCode = "en" }
                Button("RU") { session.languageCode = "ru" }
                Button(role: .cancel) { showLanguageDialog = false } label: { Text(String(localized: "cancel")) }
            }
    }
}

extension View {
    func globalNavToolbar(showHomeInDemo: Bool = true, showLogout: Bool = true) -> some View {
        modifier(GlobalNavToolbar(showHomeInDemo: showHomeInDemo, showLogout: showLogout))
    }
}
