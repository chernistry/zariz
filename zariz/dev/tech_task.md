# Technical Specification (Updated and Structured)

**Goal:**
Develop an iOS application for tracking courier deliveries from stores.

---

## 1. General Concept

The application allows stores to create orders and couriers to view available ones, accept them, and update their delivery status (e.g., “order taken,” “delivered”).

---

## 2. Main Roles

**1. Courier**

* Authentication (via phone or email)
* View active orders list
* View order details (pickup, delivery, contact info)
* Take an order into work
* Change order status (in transit, delivered)

**2. Store**

* Create orders (items, address, recipient contact)
* View order statuses
* Optionally confirm delivery completion
* Implemented as a web dashboard (no separate app)

**3. Administrator**

* Manage users (couriers, stores)
* View all orders
* Configure limits and monitor activity

---

## 3. Architecture and Components

**1. Backend Service**

* API: FastAPI / NestJS / Django REST
* Stores data on orders, users, and statuses
* JWT authentication
* REST/GraphQL API for client
* Scalable via Docker, AWS ECS, or GCP Cloud Run

**2. Database**

* PostgreSQL or Firebase Firestore
* Tables:

  * `users` (id, role, name, phone, store_id)
  * `orders` (id, store_id, courier_id, status, pickup_address, delivery_address, created_at, updated_at)
  * `status_history` (order_id, status, timestamp)

**3. iOS Application**

* Built with SwiftUI
* Flow: Login → Orders list → Order details → Status update
* Async API communication (Combine / async-await)

**4. Web Panel (optional)**

* React / Next.js / Vue
* Store authentication
* Order creation and monitoring

---

## 4. Functional Requirements

* Registration and login
* Order list view (by status: “available,” “in progress,” “delivered”)
* Filtering by store and date
* Courier updates order status
* Real-time status reflection in store dashboard
* No geolocation in MVP

---

## 5. Non-functional Requirements

* Scalability: up to 100 couriers and 50 stores
* API latency: <300 ms (p95)
* Reliability: SLA ≥99%
* Logging/monitoring via Prometheus / Grafana / Sentry
* Authentication: JWT + HTTPS

---

## 6. MVP Stage (First 2–3 Weeks)

1. Create base database schema
2. Implement CRUD API for orders
3. Add authentication and roles
4. iOS client displaying orders
5. Simple web dashboard for stores

---

## 7. Possible Extensions (v2+)

* Geolocation and routing
* Push notifications
* Delivery time estimation
* Order analytics
* Android support

---

## 8. Best Practices / Ready Solutions

* Use Clean Architecture (MVVM) for client
* Backend: FastAPI + SQLAlchemy + Alembic + Docker
* CI/CD: GitHub Actions
* Optionally reuse a delivery-app clone template (many public examples)

---

This is a standard dispatching system. The MVP will be developed by a single engineer.
Start with one VPS, a web dashboard for stores, and an iOS client.
Realtime for iOS uses APNs silent pushes + background fetch; persistent sockets in background are unrealistic. ([Apple Developer][1])

---

# 1) MVP Technical Scope (No Geolocation)

**Goal:** courier sees new orders, accepts one, and updates status until *delivered*.

**Roles:** Store, Courier, Operator/Admin.

**Scenarios:**

* Store creates order `{store_id, pickup_address, dropoff_address, items, notes}` → couriers receive notification. ([Apple Developer][1])
* Courier “claims” an order. Must be atomic and race-safe; implemented via DB transaction. ([PostgreSQL][2])
* Status flow: new → claimed → picked_up → delivered → canceled. Log every event.
* Notifications: silent APNs (`content-available=1`) to wake the app for background sync. iOS may coalesce/limit such pushes, so include polling fallback. ([Apple Developer][3])

**Non-functional:**

* Reliability of *claim*: one record—one executor. Atomic `UPDATE/SELECT FOR UPDATE SKIP LOCKED`. ([PostgreSQL][4])
* Idempotency of all POST/PUTs via `Idempotency-Key`. ([Stripe Docs][5])
* API documentation in OpenAPI 3.1. ([Swagger][6])
* Rate limiting: 429 Too Many Requests + Retry-After. ([IETF Datatracker][7])
* Security: JWT, per-object authorization, OWASP API Top-10 basics. ([IETF Datatracker][8])

**Acceptance Criteria:**
p95 API < 300 ms on 1 VPS; 100 couriers online; *claim* resistant to double-tap; push → data refresh in 30–120 s on active network. ([Apple Developer][1])

---

# 2) Architecture and Deployment

**Components:**

* **API + DB:** FastAPI/Flask + PostgreSQL.
  Tables: stores, couriers, devices, orders, order_assignments, order_events.
  Strong unique keys and CHECK constraints.
  Atomic *claim* via transaction:

  ```sql
  UPDATE orders
  SET status='claimed', courier_id=$1
  WHERE id=$2 AND status='new'
  RETURNING id;
  ```

  or queue pattern using `SELECT … FOR UPDATE SKIP LOCKED`. ([PostgreSQL][4])

* **iOS Client:** SwiftUI + SwiftData (local cache, offline). Async sync, silent pushes. ([Apple Developer][9])

* **Web Dashboard (Store/Admin):** standard SPA/SSR; separate role, RBAC.

* **Notifier:** worker sending APNs pushes. ([Apple Developer][3])

**Update Delivery:**

* iOS: APNs `content-available=1` + BGTaskScheduler; no persistent sockets. ([Apple Developer][1])
* Web panel: SSE or WebSocket; SSE sufficient for one-way push. ([MDN Web Docs][10])

**Core API:**

* `POST /orders` (store)
* `GET /orders?status=new` (courier)
* `POST /orders/{id}/claim` with Idempotency-Key (atomic)
* `POST /orders/{id}/status` → picked_up/delivered
* `POST /devices/register` (APNs token)
* OpenAPI 3.1 YAML, auto-generated SDK. ([Swagger][6])

**Security:**

* Short-lived JWT access tokens, role-based auth, BOLA checks per resource, event audit. See OWASP API Top-10. ([OWASP Foundation][11])

**Observability:**

* Logs/traces/metrics via OpenTelemetry; alerts based on SLO and error budget. ([OpenTelemetry][12])

**Deployment:**

* **Zero-budget start:** single VPS (Docker Compose: API, Postgres, Nginx/Caddy).
  Low-cost: Hetzner Cloud; OCI Always Free gives 4 OCPU / 24 GB RAM (A1). ([Hetzner][13])
* Cloud PaaS optional; one VPS is enough.
  At scale: move Postgres to managed DB, add Redis (cache/locks), dedicated push worker.

**On-prem vs Cloud:** on-prem unnecessary. One VPS or free OCI tier suffices. Scaling may later require cloud, but MVP is vendor-agnostic. ([Oracle Docs][14])

**Why not persistent socket on iOS:** iOS forbids long-lived background connections; use silent push + background tasks instead. ([Swift Forums][15])

---

[1]: https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app "Choosing Background Strategies for Your App"
[2]: https://www.postgresql.org/docs/current/explicit-locking.html "PostgreSQL Explicit Locking"
[3]: https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app "Pushing Background Updates to Your App"
[4]: https://www.postgresql.org/docs/current/sql-update.html "PostgreSQL UPDATE"
[5]: https://docs.stripe.com/api/idempotent_requests "Idempotent Requests | Stripe API Reference"
[6]: https://swagger.io/specification/ "OpenAPI Specification 3.1"
[7]: https://datatracker.ietf.org/doc/html/rfc6585 "RFC 6585 – Additional HTTP Status Codes"
[8]: https://datatracker.ietf.org/doc/html/rfc7519 "RFC 7519 – JSON Web Token (JWT)"
[9]: https://developer.apple.com/documentation/swiftdata "SwiftData Documentation | Apple Developer"
[10]: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events "Using Server-Sent Events | MDN"
[11]: https://owasp.org/API-Security/editions/2023/en/0x00-header/ "OWASP API Security Top-10 (2023)"
[12]: https://opentelemetry.io/docs/specs/otel/logs/ "OpenTelemetry Logging Spec"
[13]: https://www.hetzner.com/cloud "Hetzner Cloud Hosting and VPS Servers"
[14]: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm "Oracle OCI Always Free Resources"
[15]: https://forums.swift.org/t/problem-in-communication-with-swiftnio-when-server-is-in-a-background-app/54951 "Swift NIO background connection limitations"
