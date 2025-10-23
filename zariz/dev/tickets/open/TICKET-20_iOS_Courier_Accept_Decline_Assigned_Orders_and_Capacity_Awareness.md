Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-20] iOS (Courier) — Accept/Decline Assigned Orders and Capacity Awareness

Goal
- Enable couriers to accept or decline assigned orders within the iOS app. Reflect `assigned` state and update the action slider logic accordingly. Keep offline behavior.

Scope
1) UI/UX
- Order detail view should render an action when `status == 'assigned'` and the order is assigned to the current courier:
  - Primary slider: “Slide to accept” → calls `OrdersService.claim(id:)`.
  - Secondary button: “Decline” → calls new endpoint `POST /v1/orders/{id}/decline`.
- If not assigned to the current courier, no actions.

2) Networking
- `OrdersService`:
  - Update sync decoding to pass-through `status='assigned'`.
  - Add `decline(id:)` to call `/v1/orders/{id}/decline`.
  - Preserve offline behavior: decline should be refused offline (no draft), accept can be queued with idempotency if required.

3) Strings/Localization
- Add localized strings: `slide_to_accept`, `decline_order`, `toast_accepted`, `toast_declined`.

4) Background behavior
- Silent push on `order.assigned` triggers immediate sync. This is already handled by `OrdersSyncManager` → no extra changes required.

Plan / Changes
- Files:
  - `Zariz/Features/Orders/OrderDetailView.swift` — add branch for `assigned` status: slider → claim; decline button.
  - `Zariz/Features/Orders/OrdersService.swift` — add `decline` API; ensure `claim` works for `assigned`.
  - `Zariz/Resources/*/Localizable.strings` — new keys.

Verification
- Simulate admin assignment. Courier sees order as “Assigned” with Accept/Decline; Accept → `claimed`; Decline → order disappears from courier’s list (status `new`, no `courier_id`).

Notes
- Depends on TICKET-16 (`assigned` semantics and decline endpoint).
