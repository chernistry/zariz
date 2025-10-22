import SwiftData
import SwiftUI

struct StoreOrdersListView: View {
    @Environment(\.modelContext) private var ctx
    @State private var isLoading: Bool = false

    @Query(sort: \OrderEntity.id, order: .reverse) private var orders: [OrderEntity]

    var body: some View {
        List {
            if isLoading {
                Section { ProgressView() }
            }
            Section {
                if orders.isEmpty && !isLoading {
                    Text("store_orders_empty")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(orders) { order in
                        NavigationLink(value: order.id) {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                HStack {
                                    Text("#\(order.id)")
                                        .font(DS.Font.body.weight(.semibold))
                                        .foregroundStyle(DS.Color.textPrimary)
                                    Spacer()
                                    Text(order.status.localizedStatus)
                                        .font(DS.Font.caption)
                                        .foregroundStyle(DS.Color.textSecondary)
                                }
                                Text(order.recipientFullName.isEmpty ? order.deliveryAddress : order.recipientFullName)
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Color.textPrimary)
                                Text(order.deliveryAddress)
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                            .padding(.vertical, DS.Spacing.xs)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("store_orders_title")
        .navigationDestination(for: Int.self) { OrderDetailView(orderId: $0) }
        .task { await sync() }
        .refreshable { await sync(force: true) }
        .onAppear { ModelContextHolder.shared.context = ctx }
    }

    private func sync(force: Bool = false) async {
        if isLoading && !force { return }
        isLoading = true
        await OrdersService.shared.sync()
        isLoading = false
    }
}
