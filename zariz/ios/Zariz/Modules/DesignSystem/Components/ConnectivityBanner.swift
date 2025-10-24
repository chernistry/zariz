import SwiftUI
import Network

@Observable
final class ConnectivityMonitor {
    private let monitor = NWPathMonitor()
    private(set) var isConnected = true
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
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
    @State private var connectivity = ConnectivityMonitor()
    
    var body: some View {
        if !connectivity.isConnected {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "wifi.slash")
                Text("No Internet Connection")
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
