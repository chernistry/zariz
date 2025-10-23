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
                    if session.role == .store {
                        StoreTabView()
                    } else {
                        CourierTabView()
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
                // Bootstrap session from Keychain (silent; no UI)
                if let s = try? AuthKeychainStore.load(prompt: nil) {
                    let user = AuthenticatedUser(userId: s.userId, role: UserRole(rawValue: s.role) ?? .courier, storeIds: s.storeIds, identifier: s.identifier)
                    session.applyLogin(user: user)
                }
                pushManager.registerForPush()
                if session.storePickupAddress.isEmpty {
                    session.storePickupAddress = AppConfig.defaultPickupAddress
                }
            }
        }
        .modelContainer(for: [OrderEntity.self, OrderDraftEntity.self])
        .environmentObject(session)
        .environmentObject(toast)
        .environment(\.locale, session.locale)
        .environment(\.layoutDirection, session.isRTL ? .rightToLeft : .leftToRight)
        .backgroundTask(.appRefresh("app.zariz.orderUpdates")) {
            await OrdersService.shared.sync()
        }
    }
}

private struct CourierTabView: View {
    var body: some View {
        TabView {
            NavigationStack { OrdersListView() }
                .globalNavToolbar()
                .tabItem { Label("orders", systemImage: "list.bullet") }
            NavigationStack { ProfileView() }
                .globalNavToolbar()
                .tabItem { Label("profile", systemImage: "person.crop.circle") }
        }
    }
}
