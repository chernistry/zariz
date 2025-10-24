# Enhanced Button Components & Loading States

**Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first**

## Context
WooCommerce iOS has production-grade button components with activity indicators, disabled states, and proper accessibility. Integrate these patterns to improve Zariz's button UX during async operations (claim order, update status).

## Objective
Add `ButtonActivityIndicator` pattern and enhanced button styles to provide visual feedback during network operations without blocking UI.

## Scope
- Button with integrated activity indicator
- Loading state management for async actions
- Improved disabled/loading button styles in DS

## Implementation

### 1. Create `LoadingButton` Component
**File**: `zariz/ios/Zariz/Modules/DesignSystem/Components/LoadingButton.swift`

```swift
import SwiftUI

struct LoadingButton<Label: View>: View {
    let action: () async -> Void
    let label: () -> Label
    @State private var isLoading = false
    
    var body: some View {
        Button {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        } label: {
            ZStack {
                label().opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
        }
        .disabled(isLoading)
    }
}
```

### 2. Add Loading Button Style to DS
**File**: `zariz/ios/Zariz/Modules/DesignSystem/DesignSystem.swift`

Add after existing button styles:

```swift
struct LoadingButtonStyle: ButtonStyle {
    @Binding var isLoading: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                DS.Gradient.accent
                    .opacity(configuration.isPressed || isLoading ? 0.8 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
            .overlay {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

extension ButtonStyle where Self == LoadingButtonStyle {
    static func loading(isLoading: Binding<Bool>) -> LoadingButtonStyle {
        LoadingButtonStyle(isLoading: isLoading)
    }
}
```

### 3. Update OrderDetailView to Use Loading Buttons
**File**: `zariz/ios/Zariz/Features/Orders/OrderDetailView.swift`

Replace existing buttons with loading variants:

```swift
@State private var isClaimingOrder = false
@State private var isUpdatingStatus = false

// In body:
LoadingButton {
    await viewModel.claimOrder()
} label: {
    Text("order_detail_claim")
}
.buttonStyle(.primary)

// Or with explicit loading state:
Button("order_detail_pickup") {
    Task {
        isUpdatingStatus = true
        await viewModel.updateStatus(.pickedUp)
        isUpdatingStatus = false
    }
}
.buttonStyle(.loading(isLoading: $isUpdatingStatus))
```

### 4. Add Skeleton Loading for Lists
**File**: `zariz/ios/Zariz/Modules/DesignSystem/Components/SkeletonView.swift`

```swift
import SwiftUI

struct SkeletonView: View {
    @State private var animating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.small)
            .fill(DS.Gradient.skeleton)
            .mask(
                LinearGradient(
                    colors: [.clear, .white, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: animating ? 300 : -300)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    animating = true
                }
            }
    }
}

struct SkeletonOrderRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SkeletonView().frame(width: 120, height: 16)
            SkeletonView().frame(width: 200, height: 14)
            SkeletonView().frame(width: 80, height: 12)
        }
        .padding()
    }
}
```

### 5. Update OrdersListView with Skeleton Loading
**File**: `zariz/ios/Zariz/Features/Orders/OrdersListView.swift`

```swift
if viewModel.isLoading && viewModel.orders.isEmpty {
    ForEach(0..<5, id: \.self) { _ in
        SkeletonOrderRow()
    }
} else {
    ForEach(viewModel.orders) { order in
        OrderRow(order: order)
    }
}
```

## Testing
- [ ] Claim button shows spinner during network call
- [ ] Button disabled while loading
- [ ] Skeleton appears on initial load
- [ ] Multiple rapid taps don't trigger duplicate requests
- [ ] VoiceOver announces loading state

## Acceptance Criteria
- Buttons show activity indicator during async operations
- UI remains responsive (no blocking)
- Loading states are visually consistent across app
- Skeleton loading for empty list states

## References
- `woocommerce-ios/WooCommerce/Classes/ViewRelated/ReusableViews/ButtonActivityIndicator.swift`
- `woocommerce-ios/WooCommerce/Classes/ViewRelated/ReusableViews/GhostTableViewController.swift`

## Estimated Effort
2-3 hours
