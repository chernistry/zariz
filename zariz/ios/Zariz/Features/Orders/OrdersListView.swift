import SwiftUI
import SwiftData

struct OrdersListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \OrderEntity.id) private var orders: [OrderEntity]

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
            ModelContextHolder.shared.context = ctx
            await OrdersService.shared.sync()
        }
        .onAppear { ModelContextHolder.shared.context = ctx }
    }
}
