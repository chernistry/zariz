import SwiftData
import SwiftUI

struct OrdersListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \OrderEntity.id) private var orders: [OrderEntity]
    @EnvironmentObject private var session: AppSession
    @State private var selectedTab: Int = 0
    @State private var isLoading: Bool = true
    @State private var error: Error?

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    heroHeader
                    Picker("", selection: $selectedTab) {
                        Text("filter_new").tag(0)
                        Text("filter_active").tag(1)
                        Text("filter_done").tag(2)
                    }
                    .pickerStyle(.segmented)

                    summaryRow

                    ordersSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xl)
            }
            .refreshable {
                await loadOrders()
            }
        }
        .safeAreaInset(edge: .top) {
            ConnectivityBanner()
        }
        .navigationDestination(for: Int.self) { id in OrderDetailView(orderId: id) }
        .navigationBarTitleDisplayMode(.inline)
        .globalNavToolbar()
        .task {
            await MainActor.run { ModelContextHolder.shared.context = ctx }
            await loadOrders()
            if session.role == .courier { selectedTab = 1 }
        }
        .onAppear {
            ModelContextHolder.shared.context = ctx
            OrdersSyncManager.shared.startForegroundLoop()
            if session.role == .courier { selectedTab = 1 }
        }
        .onDisappear {
            OrdersSyncManager.shared.stopForegroundLoop()
        }
    }

    private var ordersSection: some View {
        Group {
            if isLoading && orders.isEmpty {
                skeletonList
            } else if let error {
                ErrorStateView(error: error) {
                    Task { await loadOrders() }
                }
            } else {
                let list = ordersFiltered(currentFilter)
                if list.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: DS.Spacing.md) {
                        ForEach(list) { order in
                            NavigationLink(value: order.id) {
                                OrderRowView(
                                    id: order.id,
                                    status: order.status,
                                    pickup: order.pickupAddress,
                                    delivery: order.deliveryAddress,
                                    boxes: order.boxesCount
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
    }

    private func ordersFiltered(_ filter: Filter) -> [OrderEntity] {
        switch filter {
        case .new:
            return orders.filter { $0.status == "new" || $0.status == "assigned" }
        case .active:
            return orders.filter { $0.status == "accepted" || $0.status == "picked_up" }
        case .done:
            return orders.filter { $0.status == "delivered" }
        }
    }

    private enum Filter: Hashable { case new, active, done }

    private var currentFilter: Filter {
        switch selectedTab {
        case 1: return .active
        case 2: return .done
        default: return .new
        }
    }

    private var heroHeader: some View {
        Card {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("orders_hero_title")
                        .font(DS.Font.headline)
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("orders_hero_subtitle")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                Spacer()
                Image("OrdersHero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous))
            }
            .padding(DS.Spacing.md)
        }
    }

    private var summaryRow: some View {
        let total = orders.count
        let newCount = ordersFiltered(.new).count
        let activeCount = ordersFiltered(.active).count

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.sm) {
                summaryChips(total: total, newCount: newCount, activeCount: activeCount)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    summaryChips(total: total, newCount: newCount, activeCount: activeCount)
                }
                .padding(.horizontal, DS.Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private func summaryChips(total: Int, newCount: Int, activeCount: Int) -> some View {
        SummaryChip(titleKey: "orders_summary_total", value: total)
        SummaryChip(titleKey: "orders_summary_new", value: newCount)
        SummaryChip(titleKey: "orders_summary_active", value: activeCount)
    }

    private var skeletonList: some View {
        LazyVStack(spacing: DS.Spacing.md) {
            ForEach(0..<5, id: \.self) { _ in SkeletonOrderRow() }
        }
        .transition(.opacity)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(DS.Color.brandPrimary)
            Text("no_orders_title")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.textPrimary)
            Text("no_orders_subtitle")
                .font(DS.Font.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
    
    private func loadOrders() async {
        isLoading = true
        error = nil
        await OrdersService.shared.sync()
        isLoading = false
    }
}

private struct SummaryChip: View {
    let titleKey: LocalizedStringKey
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titleKey)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text("\(value)")
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.textPrimary)
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                .fill(DS.Color.surfaceElevated)
                .shadow(color: DS.Color.brandPrimary.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
}
