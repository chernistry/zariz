import Foundation
import SwiftUI
import UserNotifications
import SwiftData

final class PushManager: NSObject, ObservableObject {
    @Published var deviceToken: String?
    private let notifiedOrdersKey = "push.notified_orders"
    private var backgroundContainer: ModelContainer?
    private var backgroundContext: ModelContext?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(onAuthConfigured(_:)), name: .authSessionConfigured, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @MainActor
    func registerForPush() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    @MainActor
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        Task { await self.registerDeviceWithBackend(token: token) }
    }

    private func authHeader() async -> String? {
        if let token = try? await AuthSession.shared.validAccessToken() { return token }
        return nil
    }

    private func registerDeviceWithBackend(token: String) async {
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent("devices/register"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let jwt = await authHeader() {
            req.addValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = ["platform": "ios", "token": token]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        _ = try? await URLSession.shared.data(for: req)
    }

    private func loadNotifiedIDs() -> Set<Int> {
        let arr = UserDefaults.standard.array(forKey: notifiedOrdersKey) as? [Int] ?? []
        return Set(arr)
    }

    private func updateNotifiedIDs(add: [Int], remove: [Int]) {
        var set = loadNotifiedIDs()
        set.formUnion(add)
        remove.forEach { set.remove($0) }
        UserDefaults.standard.set(Array(set), forKey: notifiedOrdersKey)
    }

    @MainActor
    private func ensureContext() -> ModelContext? {
        if let ctx = ModelContextHolder.shared.context {
            return ctx
        }
        if let ctx = backgroundContext { return ctx }
        do {
            let container = try ModelContainer(for: OrderEntity.self, OrderDraftEntity.self)
            backgroundContainer = container
            let context = ModelContext(container)
            backgroundContext = context
            return context
        } catch {
            Telemetry.sync.error("orders.sync.context_failure msg=\(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    private func presentNotifications(for orderIDs: [Int]) async {
        let alreadyNotified = loadNotifiedIDs()
        let unseen = orderIDs.filter { !alreadyNotified.contains($0) }
        guard !unseen.isEmpty else { return }
        guard let context = ensureContext() else { return }
        let predicate = #Predicate<OrderEntity> { orderIDs.contains($0.id) }
        let fetch = FetchDescriptor<OrderEntity>(predicate: predicate)
        guard let orders = try? context.fetch(fetch) else { return }

        let center = UNUserNotificationCenter.current()
        for order in orders where unseen.contains(order.id) {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "push_new_order_title")
            let trimmedAddress = order.deliveryAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedAddress.isEmpty {
                let shortAddress = String(trimmedAddress.prefix(80))
                content.body = String(format: String(localized: "push_new_order_body_with_address"), order.id, shortAddress)
            } else {
                content.body = String(format: String(localized: "push_new_order_body"), order.id)
            }
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "order-\(order.id)-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
        updateNotifiedIDs(add: unseen, remove: [])
    }
}

@objc private extension PushManager {
    @MainActor func onAuthConfigured(_ note: Notification) {
        guard let token = self.deviceToken else { return }
        Task { await self.registerDeviceWithBackend(token: token) }
    }
}

extension PushManager: UNUserNotificationCenterDelegate, UIApplicationDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        completionHandler(.noData)
        Task { await OrdersService.shared.sync() }
    }
}

// Notification names moved to Shared/Notifications.swift
