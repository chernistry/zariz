import SwiftUI
import SwiftData

@main
struct ZarizApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Zariz MVP")
                .padding()
        }
        .modelContainer(for: [OrderEntity.self])
    }
}

