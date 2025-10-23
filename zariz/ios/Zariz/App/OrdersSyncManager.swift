import Foundation
import Network

@MainActor
final class OrdersSyncManager: ObservableObject {
    static let shared = OrdersSyncManager()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "orders.sync.monitor")
    private var timer: Timer?
    private var isActive = false

    init() {
        monitor.start(queue: queue)
    }

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
        Telemetry.log.info("orders.sync.duration_ms=\(durationMs, privacy: .public)")
    }

    func triggerImmediateSync() {
        Task { await OrdersService.shared.sync() }
    }
}
