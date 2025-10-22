# Technical Specification (updated and structured)

## Goal
Build an iOS app to track courier deliveries from stores.

---

## 1. Concept
The app lets stores create orders. Couriers see available orders, take them, and update status (e.g., “claimed”, “delivered”).

---

## 2. Roles

1) Courier
- Sign-in (phone or email).
- View list of active orders.
- View order details (pickup, delivery, contacts).
- Claim an order.
- Update order status (in_transit, delivered).

2) Store
- Create an order (items, address, recipient contact).
- View order status.
- Optional: confirm delivery completion.
- May be a web panel (no mobile app required).

3) Admin
- Manage users (couriers, stores).
- View all orders.
- Configure constraints and monitor activity.

---

## 3. Architecture & Components

1) Backend service
- API: FastAPI / NestJS / Django REST
- Stores data about orders, users, statuses
- JWT auth
- REST/GraphQL API for client
- Scalable (Docker, AWS ECS, or GCP Cloud Run)

2) Database
- PostgreSQL or Firebase Firestore
- Tables:
  - users (id, role, name, phone, store_id)
  - orders (id, store_id, courier_id, status, pickup_address, delivery_address, created_at, updated_at)
  - status_history (order_id, status, timestamp)

3) iOS app
- SwiftUI
- Flow: sign-in → orders list → details → status change
- Async networking (Combine / async-await)

4) Web panel for stores (optional)
- React / Next.js / Vue
- Store auth
- Create orders
- Monitor order statuses

---

## 4. Functional Requirements
- Registration and sign-in
- View orders (by status: “new”, “claimed”, “delivered”)
- Filter by store and date
- Courier updates order status
- Real-time status update visible in store panel
- No geolocation for MVP

---

## 5. Non-Functional Requirements
- Scalability: up to 100 couriers and 50 stores
- API latency: p95 < 300 ms
- Reliability: SLA ≥ 99%
- Logging and monitoring (Prometheus / Grafana / Sentry)
- Authentication: JWT + HTTPS

---

## 6. MVP (first 2–3 weeks)
1. Create base DB
2. API for order CRUD
3. Auth and roles
4. iOS client with order list
5. Test store web panel

---

## 7. Potential Extensions (v2+)
- Geolocation and routing
- Push notifications
- ETA estimation
- Order analytics
- Android support

---

## 8. Best Practices / Ready Solutions
- Client: Clean Architecture (MVVM)
- Backend: FastAPI + SQLAlchemy + Alembic + Docker
- CI/CD: GitHub Actions
- Optionally: start from a “delivery-app clone” template (for learning projects)

---

This is a typical dispatch system. One engineer can deliver the MVP. Start with one VPS, a web panel for stores, and the iOS client. Real-time can be simulated with silent push + background fetch.

---

## Acceptance Criteria
- API p95 < 300 ms on 1 VPS
- 100 couriers online
- Robust courier “claim” flow (no double-claim; double tap safe)
- Push delivered → data applied within 30–120 s on active network (Apple Developer)

---

# 2) Architecture & Deployment (Deeper Guidance)

**Components**
- API + DB: FastAPI/Flask + PostgreSQL. Tables: stores, couriers, devices, orders, order_assignments, order_events. Strict unique keys and CHECK constraints on states. Atomic claim with transaction: `UPDATE orders SET status='claimed', courier_id=$1 WHERE id=$2 AND status='new' RETURNING id;` or a queue with `SELECT ... FOR UPDATE SKIP LOCKED`. (PostgreSQL)
- iOS client: SwiftUI + SwiftData (local cache, offline). Async sync, silent pushes. (Apple Developer)
- Store/Admin web: SPA/SSR; dedicated role, RBAC.
- Notifier: worker that sends APNs (Apple Developer)

**Update delivery**
- iOS: APNs `content-available=1` + BGTaskScheduler; don’t rely on background sockets. (Apple Developer)
- Web panel: SSE or WebSocket; SSE is enough for one-way push. (MDN Web Docs)

**API (core)**
- `POST /orders` (store)
- `GET /orders?status=new` (courier)
- `POST /orders/{id}/claim` with Idempotency-Key (atomic)
- `POST /orders/{id}/status` → picked_up/delivered
- `POST /devices/register` (APNs token)
- OpenAPI 3.1 yaml, auto-gen SDK (Swagger)

**Security**
- JWT access; RBAC; BOLA checks on every resource; audit events. See OWASP API Top-10. (OWASP)

**Observability**
- Logs/traces/metrics with OpenTelemetry; alerts on SLO and error budget. (OpenTelemetry)

**Deployment**
- Zero-budget start: one VPS (Docker Compose: API, Postgres, Nginx/Caddy). Low-cost providers: Hetzner Cloud; OCI Always Free offers up to 4 OCPU/24 GB RAM on A1. (Hetzner, Oracle)
- Cloud PaaS are fine, but a single VPS is enough initially. As you grow: move Postgres to managed, add Redis for cache/locks, separate notification worker.

**On‑prem vs Cloud**: on‑prem is overkill. One VPS or OCI free tier is enough. Scale later to cloud; MVP stays vendor-agnostic. (Oracle Docs)

**Why not a “persistent” socket on iOS**: iOS won’t keep a permanent background socket; use silent pushes and background tasks. (Swift Forums)

---

## References
- Apple — Choosing Background Strategies for Your App
- PostgreSQL — Explicit locking; UPDATE
- Apple — Pushing background updates to your App
- Stripe — Idempotent requests
- Swagger — OpenAPI 3.1
- RFC 6585 — Additional HTTP Status Codes
- RFC 7519 — JSON Web Token (JWT)
- Apple — SwiftData
- MDN — Server-Sent Events
- OWASP — API Security Top-10 (2023)
- OpenTelemetry — Logs
- Hetzner Cloud — VPS
- Oracle — Always Free Resources
- Swift Forums — Background communication limits

---

Notes: project is maintained by a single person with a small infra budget; prefer free or low-cost options by default.

