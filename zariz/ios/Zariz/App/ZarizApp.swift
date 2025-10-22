import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks

@main
struct ZarizApp: App {
    @UIApplicationDelegateAdaptor(PushManager.self) var pushManager
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated {
                    NavigationStack { OrdersListView() }
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
        .backgroundTask(.appRefresh("app.zariz.orderUpdates")) {
            await OrdersService.shared.sync()
        }
    }
}
