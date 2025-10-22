# Best Practices Playbook — iOS “Zariz” (2025)

A practical guide for building and scaling the Zariz iOS client (courier order tracker) under real constraints: 1 engineer, single VPS to start, lean ops. Optimizes for a fast, safe MVP with a clear path to grow.

---

## Cover

- Topic: iOS best practices 2025 for Zariz
- Audience: Mobile/iOS, Backend/API, DevOps
- Project: Zariz (store → courier delivery)
- Context: 1 engineer, 2–3 weeks for MVP, single VPS (API+Postgres+reverse proxy), SwiftUI iOS client; geolocation later; SLA ≥ 99%, API p95 < 300 ms
- Date: 2025-10-22
- Author(s): team@zariz

---

## TL;DR (≤10)

1. Client architecture: SwiftUI + MVVM + Clean (modules: Auth/Orders/Notifications), Swift 6 Concurrency (async/await, `@MainActor`, `Sendable`), DI via protocols/factories.
2. Networking: `URLSession` + async/await; typed API client; universal retry with exponential backoff + jitter; idempotency via `Idempotency-Key` for claim and status changes.
3. Data/offline: SwiftData as local cache (DTO → Entity mapping), background sync via silent pushes (`content-available=1`) + `BGTaskScheduler`, backoff polling fallback.
4. Status updates: server does atomic `claim` using a transaction/`SELECT … FOR UPDATE SKIP LOCKED`; client protects against double tap (button lock + idempotent request + UI reconciliation).
5. Observability: `OSLog` categories; crashes/breadcrumbs with Sentry; key client metrics: p95 list load, claim success rate, “push→data applied” latency ≤ 120 s.
6. Security/Privacy: JWT in Keychain, PII minimization, log redaction, ATS/TLS; never log tokens or sensitive fields; BOLA checks on API.
7. CI/CD: GitHub Actions + fastlane (build/test/lint/format/upload to TestFlight), crash symbolication, SwiftLint/SwiftFormat, Danger reports on PRs.
8. Performance: targets — cold start < 2 s, memory < 200 MB, list render ≤ 16 ms/frame; profile with Instruments.
9. Testing: unit (ViewModel/UseCase), integration (network via `URLProtocol`), UI tests for critical flows (sign-in, list, claim, change status), snapshots.
10. Roadmap: v1 without geo; v2 adds geolocation, user-facing pushes, ETA, analytics, Android.

---

## Landscape 2024–2025

- Swift 6 strict concurrency: `Sendable`, `@MainActor`, actors for protected state — fewer race conditions, better UI responsiveness.
- SwiftData stabilized for simple local caches; Observation/`@Observable` simplifies SwiftUI reactivity.
- Background tasks: `BGAppRefreshTask`/`BGProcessingTask` for background sync — preferred over long-lived sockets.
- APNs: focus on “silent” pushes for content updates; coalescing and throttling to save battery.
- iOS 18/Xcode 16: improved performance tooling (Instruments), async/await is first-class across SDKs.

---

## Patterns and When to Use Them

**Pattern A — MVP “offline-lite” (recommended initially)**
- When: 1 engineer, 1 VPS, 100 couriers / 50 stores, SLO “data applied ≤ 120 s”.
- Steps: (1) local cache using SwiftData; (2) sync via silent pushes + background task; (3) polling fallback every 2–5 minutes with backoff.
- Pros: simple, predictable, minimal dependencies; Cons: not instant real-time.
- Optional later: event aggregation, server-authoritative conflict resolution, higher-priority sync for VIP orders.

**Pattern B — “Enhanced sync” (scale-up)**
- When: higher expectations for near-real-time, geolocation/route/ETA features.
- Steps: (1) richer event model (event sourcing); (2) push/sync prioritization; (3) server de-duplication; (4) geo subsystem.
- Pros: fresher state; Cons: complexity, more telemetry and conflict resolution.

---

## Priority 1 — Order Lifecycle and Sync

### Why
- Core UX: courier sees fresh orders, can “claim” and change status without races or duplicates.

### Scope
- In: order list, details, claim, status change, cache, background updates, polling fallback.
- Out: geolocation, ETA, chats (v2).

### Decisions
- API: `GET /orders?status=new|claimed`, `POST /orders/{id}/claim` with header `Idempotency-Key`, `POST /orders/{id}/status` (picked_up/delivered).
- Idempotency: key = `deviceId:orderId:op:nonce`. Server returns last valid result for retries.
- Atomic claim: DB transaction or `SELECT … FOR UPDATE SKIP LOCKED` to prevent double assignment.
- Client UX: lock claim button during request; on network failure, retry with the same `Idempotency-Key`.

### Client Implementation
- Layers: ViewModel → UseCase → Repository → APIClient/Store (SwiftData). Protocol-driven for testability.
- List: pagination/refresh; show local cache first, then network diff patch.
- Silent pushes: on receive → fetch relevant orders → apply local patch → `@Observable` drives UI updates.
- Background: `BGAppRefreshTask` periodically (system permitting) → diff sync.

### Guardrails & SLOs
- p95 “push → data in UI” ≤ 120 s; p95 list load ≤ 700 ms (cache + network); claim success ≥ 99.5%.

### Failures & Recovery
- No network: show cache; queue local actions with idempotent retries.
- Duplicate claims: server returns 409/422 with current status; client reconciles UI to server truth.

### Snippet
```swift
// Idempotent claim request
struct ClaimRequest: Encodable { }

func claim(orderId: UUID) async throws {
  let key = IdempotencyKey.make(deviceId: deviceId, orderId: orderId, op: "claim")
  var req = URLRequest(url: base.appending(path: "/orders/\(orderId)/claim"))
  req.httpMethod = "POST"
  req.addValue(key.rawValue, forHTTPHeaderField: "Idempotency-Key")
  req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
  req.httpBody = try JSONEncoder().encode(ClaimRequest())
  let _: ClaimResponse = try await api.send(req)
}
```

---

## Priority 2 — Authentication and Secure Storage

### Decisions
- JWT access (short-lived) + refresh (via API). Store tokens in Keychain. Never log tokens.
- Biometrics (optional): `LocalAuthentication` to speed up re-entry.
- Secure defaults: ATS enforced, HTTPS only; certificate pinning optional later if policy requires it.

### Snippet
```swift
@MainActor
final class AuthStore: ObservableObject {
  @Published private(set) var session: Session?
  func signIn(login: String, code: String) async throws {
    let tokens: Tokens = try await api.signIn(login: login, code: code)
    try keychain.save(tokens)
    session = Session(tokens: tokens)
  }
}
```

---

## Priority 3 — Notifications and Background Updates

### Decisions
- APNs silent pushes (`content-available=1`) to trigger sync; user-visible pushes later.
- `BGAppRefreshTask` for periodic sync; do not rely on long-lived sockets in background.

### Snippet
```swift
// AppDelegate: register background task
BGTaskScheduler.shared.register(forTaskWithIdentifier: "app.zariz.refresh", using: nil) { task in
  Task { await SyncService.shared.refresh(); task.setTaskCompleted(success: true) }
}

// Scheduling
let request = BGAppRefreshTaskRequest(identifier: "app.zariz.refresh")
request.earliestBeginDate = Date(timeIntervalSinceNow: 15*60)
try? BGTaskScheduler.shared.submit(request)
```

---

## Area Practices

### 1) Code Style & Concurrency
- Swift 6 Concurrency: `Sendable`, `nonisolated`, `@MainActor` for UI, actors for shared resources (cache, task queue).
- Errors: well-defined `AppError` hierarchy (network/validation/server/unexpected); consistent mapping to UI states.
- Linters: SwiftLint (style, complexity), SwiftFormat (format), pre-commit hooks.

### 2) API/Module Design
- Layers: `Domain` (UseCases, models), `Data` (APIClient, Store), `UI` (SwiftUI + ViewModel). Protocols for DI and testing.
- API versioning: server OpenAPI 3.1 with autogenerated SDK (optional); keep DTO compatibility.

### 3) Data & State
- SwiftData entities: `Order`, `Store`, `User`, `StatusEvent` with essential indices; migrate by schema versions.
- Cache policy: TTL/ETag; merge network patches; server wins on conflicts.

### 4) Security
- Keychain for tokens; redact from logs/crash reports; protect symbolicated bundles.
- Avoid storing sensitive data in UserDefaults; PII minimization; encryption at rest (optional).

### 5) Privacy & Compliance
- Privacy Manifest if applicable; no ATT in MVP.
- Right-to-delete; log retention limits.

### 6) Performance & Cost
- Targets: cold start < 2 s; UI frame ≤ 16 ms; memory < 200 MB; budget network bytes.
- Instruments: Time Profiler, Allocations, Network; Signposts on critical paths.

### 7) Observability
- `OSLog` categories: `auth`, `orders`, `sync`, `network`, levels `debug/info/error`.
- Sentry: crashes, breadcrumbs (claim, status change, fatal network errors). Redaction on sensitive fields.

### 8) CI/CD
- GitHub Actions matrix (iOS 17/18), steps: build, test, lint, format, TestFlight upload via fastlane.
- Code signing: automate via App Store Connect API/fastlane match.

### 9) Testing
- Unit: ViewModel/UseCase without UI; inject fake repos/clients.
- Integration: `URLProtocol` to stub network; error scenarios (401/409/5xx, timeouts), retries.
- UI: XCUITest on “sign-in → list → claim → status change”; snapshot key screens.

### 10) Documentation
- Short ADRs, layer diagram, debug/production flags guide, release checklists.

---

## Observability & SLOs

**Key Client Metrics**
- Availability: crash-free users ≥ 99.5%.
- Latency: p95 list load ≤ 700 ms (cache+network); p95 “push→data” ≤ 120 s.
- Errors: claim errors < 0.5%; > 2 consecutive retries → log/inspect.
- Usage: active couriers/hour; offline operation share.

**Alerting**
- Sentry: crash spikes; repeated auth/network failures.
- Backend/Monitoring: API SLA, push queue, event processing speed.

**SLO Table (excerpt)**
| Surface | SLI | Target | Window | Notes |
| --- | --- | --- | --- | --- |
| Order list | p95 time launch→list | ≤ 2 s | 7/30 days | cold start |
| Sync | p95 “push→data in UI” | ≤ 120 s | 7/30 days | silent push + BGTask |
| Claim | success rate | ≥ 99.5% | 7/30 days | idempotency + retries |

---

## Reliability

- Retries with exponential backoff + jitter on transient errors; cancel via `Task` when leaving screen.
- Idempotency for all mutations: safe to retry; client stores last successful result.
- Kill switches/feature flags for risky paths; degrade to cache on network failures.

---

## Performance & Budget

- Reduce SwiftUI re-renders (observe only what's needed; `EquatableView`; memoize formatters/dates).
- Slim network payloads; use ETag/If-None-Match.

---

## Security & Privacy

- Threats: token theft, MITM, PII leaks via logs.
- Mitigations: Keychain, ATS, never log sensitive data; Sentry redaction; token rotation on compromise.

---

## Testing Strategy

- Smoke E2E on staging (fake orders) before release.
- DTO contract tests (against OpenAPI).
- Mini load run (100 concurrent claim calls with your API load tool).

---

## Risks & Trade-offs

| Risk | Impact | Likelihood | Mitigations |
| --- | --- | --- | --- |
| Sync delays > 120 s | Medium | Medium | priority pushes for “in-transit” orders; more frequent BG refresh |
| Duplicate claims | High | Low | DB atomic claim; idempotent client |
| Crashes on older devices | Medium | Low | test iOS 17/18; crash collection; hot fixes |

---

## Recommendations & Roadmap

**MVP (2–3 weeks)**
- Auth + list + details + claim + status change; SwiftData cache; background sync; Sentry/OSLog; CI (build/test/lint/TestFlight).

**Hardening & v2**
- Geolocation/routes, user-visible pushes, ETA, analytics; Android client.

---

## Appendices — Minimal Snippets

**OSLog categories**
```swift
import OSLog
let log = Logger(subsystem: "app.zariz", category: "orders")
log.info("Order list loaded: count=\(count)")
```

**Typed URLSession client**
```swift
struct API {
  let base: URL
  func send<T: Decodable>(_ req: URLRequest) async throws -> T {
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw AppError.network }
    try http.throwIfNeeded(data: data)
    return try JSONDecoder().decode(T.self, from: data)
  }
}
```

**BG task scheduling**
```swift
// Don’t overschedule; the system coalesces
request.earliestBeginDate = Date(timeIntervalSinceNow: 15*60)
```

---

## Reading List (Annotated, 2024–2025)

| Title | Date | Type | Gist | Relevance |
| --- | --- | --- | --- | --- |
| Choosing Background Strategies for Your App (Apple) | 2024-?? | Doc | Silent pushes + BGTasks over long sockets | 10/10 |
| Pushing background updates to your App (Apple) | 2024-?? | Doc | `content-available=1`, limits, battery | 10/10 |
| SwiftData Documentation (Apple) | 2025-?? | Doc | Local cache, models/migrations | 9/10 |
| What’s new in Swift Concurrency (WWDC) | 2024-?? | Talk | Strict concurrency, `Sendable`, `@MainActor` | 9/10 |
| OWASP Mobile Top-10 (2023) | 2023 | Std | Mobile threats/mitigation | 8/10 |
| URLSession Best Practices (Apple) | 2024-?? | Guide | Async/await, caching, TLS | 9/10 |
| Sentry iOS SDK | 2025-?? | Doc | Crashes/breadcrumbs/redaction | 8/10 |

---

## Checklists

**Implementation**
- [ ] Layering and DI in place
- [ ] Typed API client + retries
- [ ] SwiftData cache + background sync

**Security/Privacy**
- [ ] JWT in Keychain, never in logs
- [ ] Logs redacted
- [ ] ATS/TLS enforced

**Observability**
- [ ] OSLog categories
- [ ] Sentry wired
- [ ] SLOs on dashboards

**CI/CD & Ops**
- [ ] Actions + fastlane
- [ ] Linters/formatters
- [ ] TestFlight releases

**Release Readiness**
- [ ] ADR/diagram up-to-date
- [ ] Runbook “sync/claim failures”
- [ ] KPI dashboard

---

## Change Log

- 2025-10-22: Initial version, tailored for Zariz.
