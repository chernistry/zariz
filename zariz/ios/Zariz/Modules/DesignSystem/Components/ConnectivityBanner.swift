import SwiftUI
import Network

@Observable
@MainActor
final class ConnectivityMonitor {
    private let monitor = NWPathMonitor()
    private(set) var isConnected = true
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    deinit {
        monitor.cancel()
    }
}

struct ConnectivityBanner: View {
    @Environment(ConnectivityMonitor.self) private var connectivity
    
    var body: some View {
        if !connectivity.isConnected {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "wifi.slash")
                Text("connectivity_offline")
                    .font(DS.Font.caption)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Color.error)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

