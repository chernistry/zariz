Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-19] Web Admin — Modernize Domain Pages: Orders, Couriers Availability, Users Management

Goal
- Build Zariz domain pages on top of the Modernize (MUI) shell from TICKET-19: orders management with filters/actions, couriers availability view, and users (stores/couriers) CRUD screens.

Dependencies
- Requires TICKET-19 completed (layout/theme/app structure)
- Backend APIs:
  - Orders: already exist (`/v1/orders`, detail, assign, cancel)
  - Couriers availability: from TICKET-16 (`/v1/couriers` with load/capacity)
  - Users CRUD: if missing, open backend ticket to add `/v1/users {list,create,update,delete}` with roles+store binding (execute later if not available)

Plan
1) Orders pages (replace old ones under Modernize shell)
   - `src/pages/orders/index.tsx` — MUI DataGrid/Table with columns: id, status (incl. "assigned" → "Awaiting acceptance"), store, courier, created_at; toolbar: filters (status/store/courier/date), Export CSV button; SSE refresh on `order.*`
   - Actions per row: View, Assign, Cancel
   - `src/pages/orders/[id].tsx` — detail with MUI cards; actions Assign/Cancel; SSE-driven refresh
   - Assign modal/dialog: reuse component from TICKET-18 (`src/components/modals/AssignCourierDialog.tsx`) — do not duplicate here

2) Couriers availability
   - `src/pages/couriers/index.tsx` — table: name, load_boxes, capacity_boxes, available_boxes; filters (available_only), optional search; SSE optional refresh on `order.claimed/status_changed` to recompute load client-side (or poll periodically)

3) Users management
   - `src/pages/users/index.tsx` — list with filters by role (store/courier)
   - `src/pages/users/new.tsx` — create user form (name, phone/email, role, store binding for store users); POST `/v1/users`
   - If backend `/v1/users` is not present, mark as "execute later" and open backend ticket; wire UI but feature‑flag behind env until backend lands

4) Plumbing & polish
   - Centralize API base, auth token in `src/libs/api.ts`
   - Keep SSE client in `src/libs/sse.ts`
   - RTL support: set `theme.direction` per stored locale if present; ensure tables and inputs render properly in RTL
   - Remove legacy pages under `pages/` no longer needed

Verification
- Run `yarn dev` and navigate:
  - Orders: list, filter, assign via modal, cancel, CSV export; SSE triggers refresh
  - Order detail: live updates on SSE; Assign/Cancel buttons work
  - Couriers: shows `x/8` availability, hides full when toggle active
  - Users: list renders; new user form submits (when backend present) or gated if backend missing

Acceptance Criteria
- All domain pages live under Modernize shell with MUI components
- Filters and CSV export work; SSE refresh works for orders
- Couriers view shows accurate availability (`load/8`), respects available_only
- Users screen present and wired; if backend missing, clearly marked as pending

Notes
- Update navigation sidebar to include: Dashboard→Orders, Couriers, Users, and Logout
- Align colors and titles with `tech_task.md` terminology (EN/RU/HE keys can be added later)

---

Status: Completed

Implementation summary
- Orders
  - `zariz/web-admin/pages/orders.tsx` migrated to MUI (filters via Select/TextField, actions via Buttons, MUI Table). SSE refresh preserved; CSV export via MUI button; ‘assigned’ rendered as “Awaiting acceptance”.
  - `zariz/web-admin/pages/orders/[id].tsx` uses MUI layout, Assign modal wired.
- Couriers
  - `zariz/web-admin/pages/couriers.tsx` already implemented (TICKET-18) using MUI Table and toggle.
- Users
  - `zariz/web-admin/pages/users/index.tsx` and `zariz/web-admin/pages/users/new.tsx` added; marked pending backend `/v1/users` API. UI present; submission gated.
- Navigation
  - Links exist in `AdminLayout` to Orders, Couriers, Users; Logout via header button in Orders page.

Verification
- `cd zariz/web-admin && yarn && yarn build` → success.
- Dev run: navigate to Orders/Couriers/Users; flows behave as described; Users pages show pending notice.
