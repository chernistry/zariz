import SwiftUI
import SwiftData

struct OrdersListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \OrderEntity.id) private var orders: [OrderEntity]
    @EnvironmentObject private var session: AppSession

    var body: some View {
        List(orders) { o in
            NavigationLink(value: o.id) {
                HStack {
                    Text("#\(o.id)").bold()
                    Text(o.status).foregroundStyle(.secondary)
                }
            }
        }
        .navigationDestination(for: Int.self) { id in OrderDetailView(orderId: id) }
        .navigationTitle("Orders")
        .task {
            await MainActor.run { ModelContextHolder.shared.context = ctx }
            await OrdersService.shared.sync()
        }
        .onAppear { ModelContextHolder.shared.context = ctx }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if session.isDemoMode {
                    Button("Home") {
                        KeychainTokenStore.clear()
                        session.isAuthenticated = false
                    }
                }
                Button("Logout") {
                    KeychainTokenStore.clear()
                    session.isAuthenticated = false
                    session.isDemoMode = false
                }
            }
        }
    }
}
