import Foundation
import SwiftData
import Network

@MainActor
final class OrdersSyncManager: ObservableObject {
    static let shared = OrdersSyncManager()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "orders.sync.monitor")
    private var timer: Timer?
    private var isActive = false
    private var sse: SSEClient?

    init() {
        monitor.start(queue: queue)
    }

    func startForegroundLoop() {
        guard !isActive else { return }
        isActive = true
        scheduleNextTick()
        startSSE()
    }

    func stopForegroundLoop() {
        isActive = false
        timer?.invalidate(); timer = nil
        stopSSE()
    }

    private func scheduleNextTick() {
        guard isActive else { return }
        let base: TimeInterval = 30
        let jitter = TimeInterval(Int.random(in: -5...5))
        let interval = max(10, base + jitter)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { await self?.tick() }
        }
    }

    private func tick() async {
        defer { scheduleNextTick() }
        if monitor.currentPath.status != .satisfied { return }
        let started = Date()
        await OrdersService.shared.sync()
        let durationMs = Int((Date().timeIntervalSince(started) * 1000).rounded())
        Telemetry.sync.info("orders.sync.duration_ms=\(durationMs, privacy: .public)")
    }

    func triggerImmediateSync() {
        Task { await OrdersService.shared.sync() }
    }

    private func startSSE() {
        let sseURL = AppConfig.baseURL.appendingPathComponent("events/sse")
        sse = SSEClient(url: sseURL) { payload in
            guard let dict = payload as? [String: Any], let type = dict["type"] as? String else { return }
            if type == "order.deleted" {
                if let id = dict["order_id"] as? Int { self.deleteLocal(orderId: id) }
                else if let s = dict["order_id"] as? String, let id = Int(s) { self.deleteLocal(orderId: id) }
            }
        }
        sse?.start()
    }

    private func stopSSE() { sse?.stop(); sse = nil }

    private func deleteLocal(orderId: Int) {
        Task { @MainActor in
            guard let context = ModelContextHolder.shared.context else { return }
            let fetch = FetchDescriptor<OrderEntity>(predicate: #Predicate<OrderEntity> { $0.id == orderId })
            if let existing = try? context.fetch(fetch).first {
                context.delete(existing)
                try? context.save()
                Telemetry.sync.info("orders.sse.deleted id=\(orderId, privacy: .public)")
            }
        }
    }
}
