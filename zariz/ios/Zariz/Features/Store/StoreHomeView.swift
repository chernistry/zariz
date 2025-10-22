import SwiftData
import SwiftUI

struct StoreHomeView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.modelContext) private var ctx
    @State private var isSyncing: Bool = false

    @Query(sort: \OrderDraftEntity.createdAt, order: .reverse) private var drafts: [OrderDraftEntity]
    @Query(sort: \OrderEntity.id, order: .reverse) private var recentOrders: [OrderEntity]

    private var limitedRecentOrders: [OrderEntity] {
        Array(recentOrders.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                heroCard
                actionsCard
                if !drafts.isEmpty { draftsCard }
                if !limitedRecentOrders.isEmpty { recentOrdersCard }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.xl)
        }
        .background(DS.Color.background.ignoresSafeArea())
        .navigationTitle("store_home_title")
        .task { await performSyncIfNeeded() }
        .onAppear { ModelContextHolder.shared.context = ctx }
        .refreshable { await performSyncIfNeeded() }
    }

    private func performSyncIfNeeded() async {
        if isSyncing { return }
        isSyncing = true
        await OrdersService.shared.sync()
        isSyncing = false
    }

    private var heroCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("store_home_subtitle")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.textPrimary)
                Text("store_home_hint")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
                pricingLegend
            }
        }
    }

    private var pricingLegend: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Label("store_pricing_single", systemImage: "1.circle")
            Label("store_pricing_double", systemImage: "2.circle")
            Label("store_pricing_triple", systemImage: "3.circle")
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(DS.Color.textSecondary)
        .font(DS.Font.caption)
    }

    private var actionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                NavigationLink(destination: NewOrderView()) {
                    Label("store_home_create", systemImage: "plus.app")
                        .font(DS.Font.body.weight(.semibold))
                        .foregroundStyle(DS.Color.brandPrimary)
                }
                NavigationLink(destination: StoreOrdersListView()) {
                    Label("store_home_recent_link", systemImage: "clock")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Color.textPrimary)
                }
                Text(String(format: String(localized: "store_home_pickup_format"), session.storePickupAddress))
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    private var draftsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("store_home_pending_title")
                    .font(DS.Font.body.weight(.semibold))
                    .foregroundStyle(DS.Color.warning)
                Text(String(format: String(localized: "store_home_pending_description"), drafts.count))
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    private var recentOrdersCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("store_home_recent_header")
                    .font(DS.Font.body.weight(.semibold))
                    .foregroundStyle(DS.Color.textPrimary)
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(limitedRecentOrders) { order in
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            HStack {
                                Text("#\(order.id)")
                                    .font(DS.Font.caption.weight(.semibold))
                                    .foregroundStyle(DS.Color.textPrimary)
                                Spacer()
                                Text(order.status.localizedStatus)
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                            Text(order.deliveryAddress)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                        .padding(.vertical, DS.Spacing.xs)
                        if order.id != limitedRecentOrders.last?.id {
                            Divider().background(DS.Color.divider)
                        }
                    }
                }
            }
        }
    }
}
