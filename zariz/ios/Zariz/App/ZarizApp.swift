import SwiftUI
import SwiftData
import UserNotifications

@main
struct ZarizApp: App {
    @UIApplicationDelegateAdaptor(PushManager) var pushManager
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated {
                    Text("Welcome") // placeholder; Orders UI in Ticket 8
                } else {
                    AuthView()
                }
            }
            .onAppear {
                // Check if token exists (biometric prompt on access)
                if (try? KeychainTokenStore.load()) != nil {
                    session.isAuthenticated = true
                }
                pushManager.registerForPush()
            }
        }
        .modelContainer(for: [OrderEntity.self])
        .environmentObject(session)
    }
}
