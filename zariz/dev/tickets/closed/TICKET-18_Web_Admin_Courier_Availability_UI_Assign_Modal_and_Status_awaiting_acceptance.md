Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-18] Web Admin — Courier Availability UI, Assign Modal, and “Awaiting Acceptance” status

Goal
- Provide an admin UI to select couriers based on capacity (“x/8 boxes used”), prevent oversubscription, and reflect the `assigned` state as “Awaiting acceptance”.

Scope
1) Courier picker modal
- Invoke when clicking “Assign” on orders list/detail.
- Fetch `GET /v1/couriers?available_only=1` and display: name, `load/8`, color-coded availability (e.g., green ≤4, yellow 5–7, red 8/8 disabled).
- Allow toggling `available_only` to show all couriers (disabled entries non-clickable).

2) Order list and details
- Show status `assigned` as “Awaiting acceptance”. Keep SSE auto-refresh.
- Orders list should display assigned orders as active (they are not “new”).
- CSV export includes `status` (may be `assigned`).

3) Validation & Actions
- When selecting a courier from modal, call `POST /v1/orders/{id}/assign`.
- If server returns 409 due to capacity policy in future, show error.

Plan / Changes (updated for Modernize/MUI from TICKET-19)
- Components:
  - `src/components/modals/AssignCourierDialog.tsx` (MUI Dialog), uses `src/libs/api.ts`.
  - Wire in: `src/pages/orders/index.tsx`, `src/pages/orders/[id].tsx` to open the dialog.
- API client additions:
  - `src/libs/api.ts` — add `getCouriers(availableOnly:boolean)`.
- Styling and layout use Modernize theme (MUI); legacy Button/Input components are not used.

Verification
- Start dev server, login as Admin. Open Orders, click Assign, see modal with couriers and availability. Assign → order becomes “Awaiting acceptance”; SSE refresh works. CSV includes current status.

Notes
- This relies on backend changes in TICKET-16 (`/v1/couriers`, `assigned` status).

---

Status: Completed

Implementation summary
- Assign modal (MUI Dialog) listing couriers with capacity:
  - `zariz/web-admin/components/modals/AssignCourierDialog.tsx`
  - Fetches `GET /v1/couriers?available_only=1`; toggle to show all.
- API utility:
  - `zariz/web-admin/libs/api.ts` — added `getCouriers()` and `CourierInfo` type.
- Orders pages wired to modal and status label:
  - `zariz/web-admin/pages/orders.tsx` — opens modal on Assign, maps status `assigned` → “Awaiting acceptance”.
  - `zariz/web-admin/pages/orders/[id].tsx` — same; Assign opens modal.
- Couriers availability page (MUI Table):
  - `zariz/web-admin/pages/couriers.tsx` — shows id/name/load/capacity/available with Available-only toggle.

Verification
- Build: `cd zariz/web-admin && yarn && yarn build` → success.
- Dev: `yarn dev` → Orders Assign opens modal and assigns; list shows “Awaiting acceptance” for assigned; Couriers page lists availability.
