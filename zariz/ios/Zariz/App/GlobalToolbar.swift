import SwiftUI

struct GlobalNavToolbar: ViewModifier {
    @EnvironmentObject private var session: AppSession
    var showHomeInDemo: Bool = true
    var showLogout: Bool = true

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { session.languageCode = "he" }) {
                        HStack { Text("HE"); if session.languageCode == "he" { Image(systemName: "checkmark") } }
                    }
                    Button(action: { session.languageCode = "ar" }) {
                        HStack { Text("AR"); if session.languageCode == "ar" { Image(systemName: "checkmark") } }
                    }
                    Button(action: { session.languageCode = "en" }) {
                        HStack { Text("EN"); if session.languageCode == "en" { Image(systemName: "checkmark") } }
                    }
                    Button(action: { session.languageCode = "ru" }) {
                        HStack { Text("RU"); if session.languageCode == "ru" { Image(systemName: "checkmark") } }
                    }
                } label: {
                    Image(systemName: "globe")
                }
                if showHomeInDemo && session.isDemoMode {
                    Button(String(localized: "home")) {
                        KeychainTokenStore.clear()
                        session.isAuthenticated = false
                    }
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
    }
}

extension View {
    func globalNavToolbar(showHomeInDemo: Bool = true, showLogout: Bool = true) -> some View {
        modifier(GlobalNavToolbar(showHomeInDemo: showHomeInDemo, showLogout: showLogout))
    }
}
