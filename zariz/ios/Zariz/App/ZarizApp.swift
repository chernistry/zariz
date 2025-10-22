import AlertToast
import SwiftData
import SwiftUI
import UserNotifications
import BackgroundTasks

@main
struct ZarizApp: App {
    @UIApplicationDelegateAdaptor(PushManager.self) var pushManager
    @StateObject private var session = AppSession()
    @StateObject private var toast = ToastCenter()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated {
                    TabView {
                        NavigationStack { OrdersListView() }
                            .globalNavToolbar()
                            .tabItem { Label("orders", systemImage: "list.bullet") }
                        NavigationStack { ProfileView() }
                            .globalNavToolbar()
                            .tabItem { Label("profile", systemImage: "person.crop.circle") }
                    }
                } else {
                    AuthView()
                }
            }
            .background(DS.Color.background.ignoresSafeArea())
            .toast(
                isPresenting: $toast.isPresenting,
                duration: toast.duration,
                tapToDismiss: true,
                alert: { toast.currentToast }
            )
            .id(session.languageCode)
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
        .environmentObject(toast)
        .environment(\.locale, session.locale)
        .environment(\.layoutDirection, session.isRTL ? .rightToLeft : .leftToRight)
        .backgroundTask(.appRefresh("app.zariz.orderUpdates")) {
            await OrdersService.shared.sync()
        }
    }
}
