Agent Progress — Pass 1

Summary
- Implemented skeleton shimmer rows for Orders list.
- Added global Toast center (native SwiftUI) and Haptics.
- Hooked toasts + haptics to order actions (claim/pickup/deliver).
- Replaced context menu with confirmationDialog for language switching; consistent visibility across Auth/Orders/Profile.

Files Changed
- zariz/ios/Zariz/Modules/DesignSystem/Shimmer.swift:1
- zariz/ios/Zariz/Features/Orders/SkeletonOrderRow.swift:1
- zariz/ios/Zariz/Features/Orders/OrdersListView.swift:1
- zariz/ios/Zariz/Modules/DesignSystem/Toast.swift:1
- zariz/ios/Zariz/Modules/DesignSystem/Haptics.swift:1
- zariz/ios/Zariz/App/ZarizApp.swift:1
- zariz/ios/Zariz/Features/Orders/OrderDetailView.swift:1
- zariz/ios/Zariz/App/GlobalToolbar.swift:1
- zariz/ios/Zariz/Features/Auth/AuthView.swift:1
- zariz/ios/Zariz/Resources/*/Localizable.strings: added toast_* keys

Verification
- Open zariz/ios/Zariz.xcodeproj, Clean Build Folder, Run (iOS 17).
- Auth screen: globe → HE/AR/EN/RU updates UI and RTL.
- Orders list: initial/refresh shows 5 skeleton rows; content fades in.
- Order detail: after actions, observe success haptic + toast.

Deferred (Execute Later)
- Add SPM packages (BottomSheet, Popovers, AlertToast, Shimmer, Lottie, Kingfisher) in project.yml; resolve via Xcode (network needed).
- Convert Order Detail actions to a sticky bottom bar via .safeAreaInset or BottomSheet.
- Add AppIcon.appiconset and set ASSETCATALOG_COMPILER_APPICON_NAME.
- Expand DS tokens (typography, shadows) and apply across screens.

Next Steps (Pass 2)
- Wire SPMs with feature flags to switch between native and 3P implementations.
- Bottom action bar for Order Detail; animate transitions. [DONE: native .safeAreaInset bar]
- Accessibility + RTL polish across all screens; add identifiers for UITests.
- SPM declarations added to project.yml (BottomSheet, Popovers, AlertToast, Shimmer, Lottie, Kingfisher). Not linked to targets to avoid build errors offline; resolve and link in Xcode when network is available.
  - Pinned SwiftUI-Shimmer to 1.5.1 (latest), due to resolution error with 1.6.0.
