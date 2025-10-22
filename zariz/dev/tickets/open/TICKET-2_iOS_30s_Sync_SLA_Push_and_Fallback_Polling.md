Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-2] iOS 30s Sync SLA — Silent Push + Foreground Polling + BGTask

Goal
- Achieve ≤ 30s UI refresh latency for order status updates on iPhone/iPad (courier/store) by combining APNs silent pushes with a lightweight foreground polling fallback and BGTaskScheduler. Instrument delays per best_practices.md.

Context and Rationale
- meeting.md sets 30s status propagation target. best_practices.md recommends silent push plus periodic polling as fallback, and SwiftData for local cache.

Deliverables
1) `OrdersSyncManager` that unifies silent push triggers, BG app refresh, and foreground polling with jitter and network awareness
2) Integration into `ZarizApp` lifecycle and `PushManager` delegate
3) Minimal telemetry for delay and refresh counts
4) tech_task.md update: SLA ≤ 30s, approach details

Implementation Plan (iOS)
1. Add OrdersSyncManager
```swift
import Foundation
import Network

final class OrdersSyncManager: ObservableObject {
    static let shared = OrdersSyncManager()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "orders.sync.monitor")
    private var timer: Timer?
    private var isActive = false

    init() { monitor.start(queue: queue) }

    func startForegroundLoop() {
        guard !isActive else { return }
        isActive = true
        scheduleNextTick()
    }

    func stopForegroundLoop() {
        isActive = false
        timer?.invalidate(); timer = nil
    }

    private func scheduleNextTick() {
        guard isActive else { return }
        let base: TimeInterval = 30
        let jitter = TimeInterval(Int.random(in: -5...5))
        timer = Timer.scheduledTimer(withTimeInterval: max(10, base + jitter), repeats: false) { [weak self] _ in
            Task { await self?.tick() }
        }
    }

    private func tick() async {
        defer { scheduleNextTick() }
        // Network awareness
        if monitor.currentPath.status != .satisfied { return }
        await OrdersService.shared.sync()
    }

    // APNs silent push or BGTask hook
    func triggerImmediateSync() {
        Task { await OrdersService.shared.sync() }
    }
}
```

2. Wire into ZarizApp and PushManager
```swift
// Zariz/App/ZarizApp.swift (snippets)
@main
struct ZarizApp: App {
    @UIApplicationDelegateAdaptor(PushManager.self) var pushManager

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear { OrdersSyncManager.shared.startForegroundLoop() }
                .onDisappear { OrdersSyncManager.shared.stopForegroundLoop() }
        }
        .backgroundTask(.appRefresh("app.zariz.orderUpdates")) { // already present
            OrdersSyncManager.shared.triggerImmediateSync()
        }
    }
}

// Zariz/App/PushManager.swift (snippets)
final class PushManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // existing token handling
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // silent push (content-available:1)
        OrdersSyncManager.shared.triggerImmediateSync()
        completionHandler(.newData)
    }
}
```

3. Minimal telemetry (optional for MVP)
```swift
import os.log
enum Telemetry {
    static let log = Logger(subsystem: "app.zariz", category: "sync")
}

// Surround sync calls
let started = Date()
await OrdersService.shared.sync()
Telemetry.log.info("orders.sync.duration_ms=\(Date().timeIntervalSince(started) * 1000, format: .fixed(precision: 0))")
```

4. Respect cancellation & timeouts
- Ensure `URLSession` requests have sensible timeouts (20–30s) and respect Task cancellation per coding_rules.md.

Implementation Plan (Backend)
- Verify `/v1/devices/register` exists and APNs provider sends silent pushes on: `order.created`, `order.claimed`, `order.status_changed`. Include affected `store_id`/`courier_id` in payload if useful for filtering.
- Maintain SSE for admin web (`/events/sse`), no change needed.

Documentation Updates
- `zariz/dev/tech_task.md`: update “30–120 s” wording to “≤ 30 s”; document push + polling fallback and background task strategy; confirm iOS 17+ and BGTaskScheduler usage.

Acceptance Criteria
- When a courier changes an order status, peer devices (store/admin) reflect the update ≤ 30 s without manual refresh.
- With APNs disabled or delayed, foreground polling still delivers ≤ 30 s on active app; no excessive API load (jittered schedule).
- Background task triggers a sync upon silent push.

