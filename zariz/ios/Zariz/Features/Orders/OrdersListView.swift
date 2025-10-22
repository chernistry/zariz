import SwiftUI
import SwiftData

struct OrdersListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \OrderEntity.id) private var orders: [OrderEntity]
    @EnvironmentObject private var session: AppSession
    @State private var selectedTab: Int = 0
    @State private var isLoading: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("filter_new").tag(0)
                Text("filter_active").tag(1)
                Text("filter_done").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            TabView(selection: $selectedTab) {
                ordersList(for: .new).tag(0)
                ordersList(for: .active).tag(1)
                ordersList(for: .done).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationDestination(for: Int.self) { id in OrderDetailView(orderId: id) }
        .navigationTitle("orders")
        .globalNavToolbar()
        .task {
            await MainActor.run { ModelContextHolder.shared.context = ctx }
            isLoading = true
            await OrdersService.shared.sync()
            isLoading = false
        }
        .onAppear { ModelContextHolder.shared.context = ctx }
    }

    @ViewBuilder
    private func ordersList(for filter: Filter) -> some View {
        let list = ordersFiltered(filter)
        if isLoading {
            List {
                ForEach(0..<5, id: \.self) { _ in SkeletonOrderRow() }
            }
            .listStyle(.plain)
        } else if list.isEmpty {
            ContentUnavailableView("no_orders_title", systemImage: "tray", description: Text("no_orders_subtitle"))
        } else {
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

    private func ordersFiltered(_ filter: Filter) -> [OrderEntity] {
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
