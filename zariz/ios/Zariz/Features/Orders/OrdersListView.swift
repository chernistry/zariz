import SwiftData
import SwiftUI
import SwiftUIX

struct OrdersListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \OrderEntity.id) private var orders: [OrderEntity]
    @EnvironmentObject private var session: AppSession
    @State private var selectedTab: Int = 0
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
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
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.xl)
            }
            .refreshable {
                isLoading = true
                await OrdersService.shared.sync()
                isLoading = false
            }
        }
        .navigationDestination(for: Int.self) { id in OrderDetailView(orderId: id) }
        .navigationTitle("orders")
        .globalNavToolbar()
        .task {
            await MainActor.run { ModelContextHolder.shared.context = ctx }
            isLoading = true
            await OrdersService.shared.sync()
            isLoading = false
            // Default to "Active" for couriers so assigned orders are visible
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
            if isLoading {
                VStack(spacing: DS.Spacing.lg) {
                    ActivityIndicator()
                        .style(.large)
                        .foregroundColor(DS.Color.brandPrimary)
                    Text("loading_orders")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxl)
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
            return orders.filter { $0.status == "claimed" || $0.status == "picked_up" }
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
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("orders_hero_title")
                            .font(DS.Font.title)
                            .foregroundStyle(DS.Color.textPrimary)
                        Text("orders_hero_subtitle")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    Spacer()
                }
                Image("OrdersHero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous))
            }
        }
    }

    private var summaryRow: some View {
        let total = orders.count
        let newCount = ordersFiltered(.new).count
        let activeCount = ordersFiltered(.active).count

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.md) {
                summaryChips(total: total, newCount: newCount, activeCount: activeCount)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DS.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    summaryChips(total: total, newCount: newCount, activeCount: activeCount)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
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
}

private struct SummaryChip: View {
    let titleKey: LocalizedStringKey
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(titleKey)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text("\(value)")
                .font(DS.Font.numeric(weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
        }
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                .fill(DS.Color.surfaceElevated)
                .shadow(color: DS.Color.brandPrimary.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}
