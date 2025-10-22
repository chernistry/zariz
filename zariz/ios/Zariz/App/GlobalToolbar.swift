import SwiftUI

struct GlobalNavToolbar: ViewModifier {
    @EnvironmentObject private var session: AppSession
    var showHomeInDemo: Bool = true
    var showLogout: Bool = true

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if showHomeInDemo && session.isDemoMode {
                    Button("Home") {
                        KeychainTokenStore.clear()
                        session.isAuthenticated = false
                        // Keep demo flag as is, user can toggle it again on login screen
                    }
                }
                if showLogout {
                    Button("Logout") {
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
