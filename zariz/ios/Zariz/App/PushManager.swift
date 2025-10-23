import Foundation
import SwiftUI
import UserNotifications
import SwiftData

@MainActor
final class PushManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    @Published var deviceToken: String?

    func registerForPush() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        Task { await self.registerDeviceWithBackend(token: token) }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        OrdersSyncManager.shared.triggerImmediateSync()
        completionHandler(.newData)
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
}
