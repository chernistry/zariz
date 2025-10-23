Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-16] Backend — Courier Capacity, Assignment Acceptance, and Availability API

Goal
- Add capacity-aware assignment with an intermediate `assigned` status and explicit courier acceptance. Expose an API to surface courier load/availability to the admin web.

Context
- Meeting confirms: Admin assigns; courier accepts/declines; each courier has 8 boxes capacity. Current backend jumps to `claimed` during admin assignment, which is not aligned with the expected flow. This ticket corrects the backend behavior and adds capacity checks.

Scope
1) Model & transitions
- Status cascade becomes: `new → assigned → claimed → picked_up → delivered`; `canceled` remains terminal (admin-only). Enforce monotonic transitions.
- Add per-courier capacity: `users.capacity_boxes` (default 8). Capacity may be made configurable later per policy.

2) Assignment semantics (admin)
- `POST /v1/orders/{id}/assign` must set `status=assigned` and `courier_id=...`, emit `order.assigned` SSE and silent push.
- If order is not in an assignable state (`delivered`, `canceled`) → 400.

3) Acceptance (courier)
- Reuse `POST /v1/orders/{id}/claim` to accept when `status in {new, assigned}`. For `assigned`, only the assigned courier may accept; reject otherwise with 409.
- Enforce capacity on acceptance: if `current_load(boxes in {claimed,picked_up}) + order.boxes_count > capacity_boxes` → 409. Implement within a DB transaction with a lock on the courier row to avoid race.

4) Decline (courier)
- Add `POST /v1/orders/{id}/decline` (courier only) to revert `assigned → new` and `courier_id = NULL`. Emit `order.assigned_declined` SSE and silent push. Idempotent.

5) Availability API (admin web)
- `GET /v1/couriers?available_only=0|1` returns: `[{ id, name, capacity_boxes, load_boxes, available_boxes }]` sorted by `available_boxes DESC, id ASC`.
- `load_boxes = SUM(boxes_count) WHERE status IN ('claimed','picked_up')`; zero when none.

6) Filters & consistency
- Allow list filter `status=assigned` (already enabled in code). Ensure OpenAPI docs updated.

Plan
- DB: Alembic migration to add `users.capacity_boxes INTEGER NOT NULL DEFAULT 8`.
- Routes:
  - Update `POST /v1/orders/{id}/assign`: set `status='assigned'` (not `claimed`), push SSE+silent.
  - Update `POST /v1/orders/{id}/claim`: allow accept for `assigned` iff same `courier_id`; enforce capacity with transaction.
  - Add `POST /v1/orders/{id}/decline` (courier); set `status='new'`, `courier_id=NULL`, emit SSE+silent.
  - Add `GET /v1/couriers` with computed load.
- Security: RBAC (`admin` for assign; `courier` for claim/decline). BOLA checks on single-order endpoints.
- Observability: JSON log fields include `courier_id`, `order_id`, `load_boxes`, `capacity_boxes` on assignment acceptance.

Verification
- Unit tests (pytest):
  - Assign → claim by assigned courier succeeds; status becomes `claimed`.
  - Assign → claim by another courier fails (409).
  - Capacity overflow at acceptance returns 409.
  - Decline sets order back to `new`, clears `courier_id`.
  - `GET /v1/couriers?available_only=1` excludes couriers at full capacity.

File references / Changes
- Backend:
  - `zariz/backend/app/db/models/user.py` — add `capacity_boxes: int`.
  - `zariz/backend/app/api/routes/orders.py` — adjust assign, claim; add decline.
  - `zariz/backend/app/api/routes/couriers.py` — new list endpoint.
  - `zariz/backend/alembic/versions/*` — migration for `capacity_boxes`.
  - Tests under `zariz/backend/tests/` for new flows.

Notes
- For MVP we compute load dynamically; a counter column (occupied) may be introduced later for constant-time checks.
- Keep idempotency behavior consistent; support `Idempotency-Key` on accept/decline calls.
