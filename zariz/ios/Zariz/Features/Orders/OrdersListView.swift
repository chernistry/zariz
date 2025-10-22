import SwiftUI
import SwiftData

struct OrdersListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \OrderEntity.id) private var orders: [OrderEntity]
    @EnvironmentObject private var session: AppSession
    @State private var filter: Filter = .new
    @State private var isLoading: Bool = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading orders...")
            } else if ordersFiltered().isEmpty {
                ContentUnavailableView("No orders", systemImage: "tray", description: Text("Pull to refresh or check back later"))
            } else {
                let list = ordersFiltered()
                List(list) { o in
                    NavigationLink(value: o.id) {
                        OrderRowView(id: o.id, status: o.status, pickup: o.pickupAddress, delivery: o.deliveryAddress)
                    }
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable {
                    isLoading = true
                    await OrdersService.shared.sync()
                    isLoading = false
                }
            }
        }
        .navigationDestination(for: Int.self) { id in OrderDetailView(orderId: id) }
        .navigationTitle("Orders")
        .toolbar { ToolbarItem(placement: .principal) { filterPicker } }
        .task {
            await MainActor.run { ModelContextHolder.shared.context = ctx }
            isLoading = true
            await OrdersService.shared.sync()
            isLoading = false
        }
        .onAppear { ModelContextHolder.shared.context = ctx }
        .globalNavToolbar()
    }

    @ViewBuilder
    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            Text("New").tag(Filter.new)
            Text("Active").tag(Filter.active)
            Text("Done").tag(Filter.done)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 320)
    }

    private func ordersFiltered() -> [OrderEntity] {
        switch filter {
        case .new:
            return orders.filter { $0.status == "new" }
        case .active:
            return orders.filter { $0.status == "claimed" || $0.status == "picked_up" }
        case .done:
            return orders.filter { $0.status == "delivered" }
        }
    }

    private enum Filter: Hashable { case new, active, done }
}
