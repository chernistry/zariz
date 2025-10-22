import SwiftUI

struct DemoExitToolbar: ViewModifier {
    @EnvironmentObject private var session: AppSession

    func body(content: Content) -> some View {
        content.toolbar {
            if session.isDemoMode {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Home") {
                        KeychainTokenStore.clear()
                        session.isAuthenticated = false
                    }
                }
            }
        }
    }
}

extension View {
    func demoExitToolbar() -> some View { modifier(DemoExitToolbar()) }
}
