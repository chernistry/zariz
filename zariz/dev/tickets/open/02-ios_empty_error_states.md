# Empty States & Error Handling UI Components

**Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first**

## Context
WooCommerce iOS has polished empty state and error views with illustrations, clear messaging, and action buttons. Integrate these patterns to improve Zariz's UX when lists are empty or errors occur.

## Objective
Create reusable empty state and error components with consistent styling, illustrations, and recovery actions.

## Scope
- Empty state view for order lists
- Error state view with retry action
- Inline error messages
- Network connectivity indicator

## Implementation

### 1. Create EmptyStateView Component
**File**: `zariz/ios/Zariz/Modules/DesignSystem/Components/EmptyStateView.swift`

```swift
import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(DS.Color.textSecondary)
            
            VStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.textPrimary)
                
                Text(message)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(.primary)
                .frame(maxWidth: 280)
            }
        }
        .padding(DS.Spacing.xl)
    }
}
```

### 2. Create ErrorStateView Component
**File**: `zariz/ios/Zariz/Modules/DesignSystem/Components/ErrorStateView.swift`

```swift
import SwiftUI

struct ErrorStateView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DS.Color.error)
            
            VStack(spacing: DS.Spacing.xs) {
                Text("error_title")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.textPrimary)
                
                Text(error.localizedDescription)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: retryAction) {
                Label("error_retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.primary)
            .frame(maxWidth: 280)
        }
        .padding(DS.Spacing.xl)
    }
}
```

### 3. Create InlineErrorView Component
**File**: `zariz/ios/Zariz/Modules/DesignSystem/Components/InlineErrorView.swift`

```swift
import SwiftUI

struct InlineErrorView: View {
    let message: String
    var dismissAction: (() -> Void)?
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DS.Color.error)
            
            Text(message)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.textPrimary)
            
            Spacer()
            
            if let dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
    }
}
```

### 4. Create ConnectivityBanner Component
**File**: `zariz/ios/Zariz/Modules/DesignSystem/Components/ConnectivityBanner.swift`

```swift
import SwiftUI
import Network

@Observable
class ConnectivityMonitor {
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
    @Environment(ConnectivityMonitor.self) private var connectivity
    
    var body: some View {
        if !connectivity.isConnected {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "wifi.slash")
                Text("connectivity_offline")
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
```

### 5. Update OrdersListView with States
**File**: `zariz/ios/Zariz/Features/Orders/OrdersListView.swift`

```swift
var body: some View {
    ZStack {
        if viewModel.isLoading && viewModel.orders.isEmpty {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonOrderRow()
            }
        } else if let error = viewModel.error {
            ErrorStateView(error: error) {
                Task { await viewModel.loadOrders() }
            }
        } else if viewModel.orders.isEmpty {
            EmptyStateView(
                icon: "tray",
                title: "orders_empty_title",
                message: "orders_empty_message",
                actionTitle: "orders_empty_refresh",
                action: {
                    Task { await viewModel.loadOrders() }
                }
            )
        } else {
            List {
                ForEach(viewModel.orders) { order in
                    OrderRow(order: order)
                }
            }
        }
    }
    .safeAreaInset(edge: .top) {
        ConnectivityBanner()
    }
}
```

### 6. Add Localized Strings
**File**: `zariz/ios/Zariz/Resources/en.lproj/Localizable.strings`

```
/* Empty States */
"orders_empty_title" = "No Orders Yet";
"orders_empty_message" = "New orders will appear here when stores create them";
"orders_empty_refresh" = "Refresh";

/* Error States */
"error_title" = "Something Went Wrong";
"error_retry" = "Try Again";

/* Connectivity */
"connectivity_offline" = "No Internet Connection";
```

### 7. Update ViewModel with Error Handling
**File**: `zariz/ios/Zariz/Features/Orders/OrdersListViewModel.swift`

```swift
@Published private(set) var error: Error?

func loadOrders() async {
    isLoading = true
    error = nil
    
    do {
        orders = try await repository.fetchOrders()
    } catch {
        self.error = error
    }
    
    isLoading = false
}
```

### 8. Add ConnectivityMonitor to App
**File**: `zariz/ios/Zariz/ZarizApp.swift`

```swift
@State private var connectivity = ConnectivityMonitor()

var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(connectivity)
    }
}
```

## Testing
- [ ] Empty state shows when no orders
- [ ] Error state shows on network failure
- [ ] Retry button reloads data
- [ ] Connectivity banner appears when offline
- [ ] Banner dismisses when connection restored
- [ ] VoiceOver reads all states correctly

## Acceptance Criteria
- Empty states have clear messaging and optional actions
- Error states show user-friendly messages with retry
- Connectivity banner appears/disappears smoothly
- All states are accessible

## References
- `woocommerce-ios/WooCommerce/Classes/ViewRelated/ReusableViews/EmptyListMessageWithActionView.swift`
- `woocommerce-ios/WooCommerce/Classes/ViewRelated/ReusableViews/ErrorSectionHeaderView.swift`
- `woocommerce-ios/Modules/Sources/PointOfSale/Presentation/Reusable Views/POSListEmptyView.swift`
- `woocommerce-ios/Modules/Sources/PointOfSale/Presentation/Reusable Views/POSConnectivityView.swift`

## Estimated Effort
3-4 hours

## Dependencies
- Requires completion of `ios_enhanced_button_components.md` for consistent button styles
