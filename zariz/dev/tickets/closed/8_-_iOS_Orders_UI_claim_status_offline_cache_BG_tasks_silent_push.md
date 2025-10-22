Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: iOS Orders UI, claim/status, offline cache, BG tasks + silent push

Objective
- Implement Orders list/detail screens, claim and status update calls.
- Sync with backend; persist in SwiftData for offline-first.
- Handle silent push + background refresh to update data.

Deliverables
- `OrdersListView` and `OrderDetailView` with actions.
- `OrdersService` to fetch/claim/update status.
- Background task registration and silent push handler.

Implementation Summary
- DTO + service: `zariz/ios/Zariz/Features/Orders/OrdersService.swift` (sync, claim, update); adds Idempotency-Key header on writes.
- UI: `zariz/ios/Zariz/Features/Orders/OrdersListView.swift` (list with @Query), `zariz/ios/Zariz/Features/Orders/OrderDetailView.swift` (actions enabled by status).
- Persistence glue: `zariz/ios/Zariz/Data/Persistence/ModelContextHolder.swift` to allow background delegate-triggered sync.
- App wiring: `zariz/ios/Zariz/App/ZarizApp.swift` shows Orders after auth; registers `.backgroundTask(.appRefresh("app.zariz.orderUpdates"))` to sync in background.
- Silent push: `zariz/ios/Zariz/App/PushManager.swift` handles `didReceiveRemoteNotification` and triggers sync.
- Info.plist updated with `UIBackgroundModes` (remote-notification, fetch) and `BGTaskSchedulerPermittedIdentifiers`.

How to Verify
- `cd zariz/ios && xcodegen generate && open Zariz.xcodeproj`
- Log in, view Orders list, open detail; press Claim/Picked up/Delivered and observe status & list refresh.
- Simulate push/background refresh (Xcode Debug → Simulate Background Fetch) — Orders sync runs.

Notes
- UI uses simple SwiftUI components; can be styled later via DesignSystem.
- Background sync requires capabilities set in Xcode; silent push delivery needs proper APNs entitlements.

