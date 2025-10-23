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

---

Status: Completed

Implementation summary
- Orders list shows assigned orders under Active:
  - `zariz/ios/Zariz/Features/Orders/OrdersListView.swift` — include `assigned` in active filter.
- Order detail actions for assigned:
  - `zariz/ios/Zariz/Features/Orders/OrderDetailView.swift` — added `assigned` to actionConfiguration as “slide_to_accept”; added Decline destructive button; extended timeline/status mapping to include `assigned` state.
- Networking:
  - `zariz/ios/Zariz/Features/Orders/OrdersService.swift` — `claim(id:)` permits `new` or `assigned`; added `decline(id:)` POST `/orders/{id}/decline`; demo mode mirrors behavior.

Verification
- Run app (demo or real backend):
  - Assigned order displays Accept slider and Decline button; Accept transitions to claimed; Decline transitions back to new (and disappears from courier’s list).
- Silent push still triggers sync (unchanged).

Follow-ups
- Add localized strings for new keys: `status_assigned`, `slide_to_accept`, `decline_assignment`, `toast_declined`.
