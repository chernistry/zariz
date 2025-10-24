import AlertToast
import SwiftData
import SwiftUI
import SwiftUIX
import UserNotifications
import BackgroundTasks

@main
struct ZarizApp: App {
    @UIApplicationDelegateAdaptor(PushManager.self) var pushManager
    @StateObject private var session = AppSession()
    @StateObject private var toast = ToastCenter()
    @State private var isRestoringSession = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isRestoringSession {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                } else if session.isAuthenticated {
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
            .task {
                // Bootstrap session from Keychain (silent; no UI)
                if let s = try? AuthKeychainStore.load(prompt: nil) {
                    Telemetry.auth.info("auth.bootstrap.start userId=\(s.userId)")
                    let user = AuthenticatedUser(userId: s.userId, role: UserRole(rawValue: s.role) ?? .courier, storeIds: s.storeIds, identifier: s.identifier)
                    await AuthSession.shared.restoreUser(user)
                    do {
                        _ = try await AuthService.shared.refresh()
                        await MainActor.run {
                            session.applyLogin(user: user)
                        }
                        Telemetry.auth.info("auth.bootstrap.success")
                    } catch {
                        Telemetry.auth.error("auth.bootstrap.refresh_failed error=\(error.localizedDescription)")
                        // Clear invalid session
                        await AuthSession.shared.clear()
                    }
                } else {
                    Telemetry.auth.info("auth.bootstrap.no_stored_session")
                }
                await MainActor.run {
                    isRestoringSession = false
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
