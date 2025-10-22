# Best Practices Playbook — iOS “Zariz” (2025)

iOS Client and FastAPI Backend Development Practices (2024–2025)
iOS Client: Architecture, Offline, and Performance

**Architecture (SwiftUI + MVVM/Clean):** Use Clean Architecture based on MVVM for modularity and testability of SwiftUI applications (see github.com). Divide the code into layers: UI (SwiftUI View and ViewModel), domain (business logic, use cases), data (network, DB), and infrastructure (configurations) (github.com). This structure simplifies maintenance, dependency injection, and unit testing, even for a single developer. SwiftUI 2024+ allows minimal controller code, but keeping the MVVM pattern ensures scalability. Note: while some claim SwiftUI can work without heavy ViewModels thanks to SwiftData and @Observable, for complex apps architectural separation is justified (dimillian.medium.com).

**Synchronization and Offline-first:** Implement local caching with SwiftData—a new ORM-like Apple library for data (CoreData alternative in iOS 17+). Store key data (orders, statuses) on-device so the app works offline. On launch or connection restore, perform async sync: show local data first, then refresh from server via async/await. This offline-first approach improves responsiveness and reliability. Data persistence requires minimal code: declare @Model entities in SwiftData and use @Query in SwiftUI for auto UI-sync (reddit.com). Server updates may be triggered by timer or push (see below); ensure network calls run on background priority to avoid blocking the main thread.

**Push Notifications and Background Updates:** For “real-time” behavior, use silent push notifications (Remote Notifications with content-available:1) that wake the app in background. Register users for push: request UNUserNotificationCenter permission (.alert, .badge, .sound), then call UIApplication.shared.registerForRemoteNotifications() (after approval)—this yields the device token for APNs. Send it to the backend (endpoint /devices/register) (github.com, github.com). When events occur (new order, status change), the server pushes through APNs to registered devices. The notification has content-available:1 and no alert, so iOS silently wakes the app for background sync. Client side: handle background notifications with SwiftUI’s .backgroundTask(.appRefresh) modifier to trigger data sync upon push (swiftwithmajid.com). Example:

```swift
@main
struct MyApp: App {
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup { ContentView() }
        .backgroundTask(.appRefresh("orderUpdates")) {
            await syncOrdersFromAPI()  // background fetch
        }
        .onChange(of: phase) { newPhase in
            if newPhase == .background {
                scheduleAppRefresh()
            }
        }
    }
}
```

In this example, when the app goes to background, BGTaskScheduler plans the refresh; on receiving a silent push, iOS executes the task with ID "orderUpdates" (swiftwithmajid.com). iOS may delay or group silent pushes, so add a fallback—periodic API polling. Avoid excessive push frequency; Apple classifies them as low priority.

**UI Performance:** SwiftUI in Swift 6 renders fast, but follow best practices: use .id() identifiers for diffing lists, LazyVStack/ScrollView for long lists, and avoid heavy logic in View bodies. Run long operations asynchronously (async/await) on global queues. Profile with Xcode Instruments (Time Profiler, SwiftUI previews) to detect bottlenecks. For 100–500 users, UI performance won’t bottleneck if these measures are followed: rendering order lists and details should remain smooth. For heavy computation (routing, sorting), delegate to background tasks (BGProcessingTask). Verify UI updates post-push within p95 ≤ 30–120 s—pushes typically arrive in seconds, with extra time for background fetch and redraw.

**Mobile Observability:** Add crash reporting and logging. Use Sentry SDK or Firebase Crashlytics—no custom server needed. For live debugging, log via OSLog (visible in Console). Include simple analytics—launch counts, active users (via App Center, Firebase Analytics, or Apple App Analytics). This helps ensure users aren’t facing critical issues.

**CI/CD for iOS:** Automate builds and testing. GitHub Actions offers macOS runners. Steps: run XCTest unit tests, lint with SwiftLint, autoformat with SwiftFormat, and build .ipa. Use fastlane for TestFlight upload—fastlane simplifies code signing and App Store Connect upload (brightinventions.pl). Configure Fastlane Match for cert/profile management via repository to simplify CI signing (brightinventions.pl). Automate TestFlight deployment: a push to main triggers a workflow that builds, uploads via fastlane upload_to_testflight (or pilot), and notifies testers. Set CI alerts (e.g., GitHub → Slack/email) for failed builds/tests. Automation ensures quality and saves 24/7 maintenance effort.

---

### Backend: FastAPI (Python) vs Node/NestJS

**Why FastAPI:** For a solo developer with tight deadlines, Python/FastAPI is ideal. While Node/NestJS can outperform Python, for 100–500 users the difference is negligible—development speed matters more (reddit.com). FastAPI enables quick API creation via Pydantic and auto OpenAPI docs—type validation and docs “out of the box” (medium.com). Excellent DX: dynamic typing speeds prototyping, type hints add TS-like confidence. For a 2–3 week MVP, this is critical.

**Performance:** Python is slower than Node/V8, but FastAPI (ASGI, uvicorn/Starlette) achieves competitive performance (reddit.com). ExpressJS may deliver ~3× higher throughput under stress (planeks.net), but for p95 ≤ 300 ms FastAPI suffices. Proper async DB drivers yield Node-level latency (tens of ms). Startup time is slightly longer but irrelevant for always-on VPS. For serverless (Cloud Run), cold starts are higher but mitigable with minimum instance count.

**Ecosystem:** Python offers rich libraries—valuable for analytics, reports, or optimization. Mature DB tools (SQLAlchemy, asyncpg), migrations (Alembic), JWT auth (PyJWT/OAuth2) (github.com). Code is shorter and clearer than NestJS equivalents, reducing bugs. Developer speed outweighs infra cost at early stages (reddit.com). Many startups never reach the scale needing extreme optimization—avoid premature over-engineering (reddit.com).

**When Node/NestJS Fits Better:** For TypeScript-proficient teams or enterprise-grade systems with many modules, NestJS offers strict modularity and Angular-like structure. It’s stronger for heavy real-time (websockets, chats) due to event-loop advantages, though FastAPI also supports WebSocket. For this MVP, NestJS would add boilerplate (modules, providers) and slow delivery (leapcell.io, medium.com). Python excels at fast iteration, standard libs, and domain-specific use (geocoding, ML) (reddit.com). Later optimization can offload hotspots to Go/Rust microservices or C-extensions (reddit.com).

**Conclusion:** FastAPI is optimal for small-scale, fast development. As noted in community discussions, “shipping is more important than squeezing RPS” (reddit.com). A FastAPI backend easily supports 100–500 users with simpler maintenance and lower cost.

---

### Infrastructure and Deployment

**Single VPS vs PaaS:** Start with one inexpensive VPS (Hetzner, OCI Ampere). A 2–4 vCPU, 4–24 GB instance is enough. Use Docker Compose: FastAPI, PostgreSQL, and proxy (Nginx/Caddy). This minimizes complexity—manageable by one engineer. Alternative: PaaS (Railway, Fly.io, Render, GCP Cloud Run) offers autoscaling, HTTPS, and low admin. For MVP, a VPS suffices, but Cloud Run or Fly.io provides zero-maintenance options. Cloud Run scales to zero (beware cold starts). Fly.io/Railway deploy easily via CLI with free tiers. VPS offers stability and control; PaaS offloads OS/security patching. Balanced path: start on VPS, later split components (managed DB, push worker).

**Running FastAPI with HTTPS:** On VPS, use a reverse proxy (Nginx or Caddy). Caddy auto-generates Let’s Encrypt certificates—minimal setup. Example Caddyfile:

```
yourdomain.com {
    reverse_proxy 0.0.0.0:8000
}
```

Caddy handles HTTPS on 443, redirect 80→443. Nginx requires TLS config and proxy_pass [http://app:8000](http://app:8000). Ensure backend runs via HTTPS—iOS ATS requires it. On Cloud Run/Render, HTTPS is automatic.

**Apple Push Notifications (APNs) Server:** Backend must send APNs push. Obtain .p8 key (Key ID, Team ID, Issuer ID) from Apple Developer Account. Use python-apns2 for FastAPI (HTTP/2 API). Send pushes directly or via background worker (Celery/RQ). Example pseudo-code:

```python
from hypercorn.asyncio import APNsClient

client = APNsClient(credentials=(AUTH_KEY_PATH, KEY_ID), team_id=TEAM_ID)
payload = {"aps": {"content-available": 1}, "order_id": 123}
client.send_notification(device_token, payload, push_type="background")
```

Encapsulate this in a service. See PushNotificationServerFramework on GitHub for APNs integration (github.com). Ensure outbound 443 access and proper headers: apns-topic (bundle ID) and apns-push-type: background (developer.apple.com).

**Backend Logging/Monitoring:** Enable structured request/error logging. Uvicorn logs by default; add middleware for extended logs. Output to stdout—Docker captures logs. For metrics, use Prometheus + Grafana, or just monitor system metrics initially. Track API p95 < 300 ms. Add error reporting—Sentry Python SDK captures exceptions automatically. For PaaS, use built-in observability (e.g., GCP Stackdriver). Alerts: configure Sentry or uptime monitors to Telegram/email on errors. Minimal alerting gives you fault awareness without 24/7 on-call.

**Deployment:** Automate to avoid manual prod updates. On VPS, deploy via GitHub Actions: build Docker image, push to registry, and auto-update container (Watchtower). Simpler: SSH → `docker-compose pull && docker-compose up -d`. GitHub Actions supports SSH/CD. For PaaS, use CLI or git-based deploy. Automate HTTPS renewal (Caddy or certbot cron). Ensure auto-start on reboot (Docker restart or systemd service).

**Scaling Path:** For growth, plan migration: move DB to managed service, add Redis for caching/locking, isolate push worker. Up to 500 users, one instance suffices.

---

### Example Boilerplates

**FastAPI + PostgreSQL + Alembic + JWT + APNs:** In 2024–2025 several templates emerged. Example: `fastapi_postgres_async_jwt_alembic` demonstrates async FastAPI with SQLAlchemy, Alembic migrations, and JWT auth (github.com). Includes registration, login, refresh, etc.—adaptable to courier/store roles. For push, check PushNotificationServerFramework (github.com) with /devices/register and /push/send endpoints using apns2. Another: RealWorld FastAPI example—good structure (routers, services, models) and JWT auth. If preferring TS, NestJS realworld app exists, but we stay with Python. The FastAPI community shares many starter kits (e.g., BetterStack JWT/OAuth2 templates) (betterstack.com).

**SwiftUI MVVM + SwiftData + Push + BGTask:** Many modern open-source SwiftUI apps show clean architecture. See Clean-Architecture-SwiftUI-MVVM (reddit.com, github.com)—layered app with local storage (easily swapped for SwiftData) and tests. Also, NativeAppTemplate-Free-iOS (reddit.com)—production-grade SwiftUI iOS 17 app with @Observable, SwiftLint, onboarding, auth, and CRUD. Use it as a base, adding order logic. For push examples, check Apple’s sample code and WWDC sessions: “The Push Notifications Primer” (WWDC20-10095) and “Background Tasks”. Also see Majid’s background-task guide (swiftwithmajid.com). Our BGTaskScheduler example follows this API.

For domain-related learning, study open food-delivery demo apps—they offer UI and state-management ideas (Combine for network updates).

**Tip:** Start with minimal flow (Login → Orders → Details → Actions). Expand incrementally. Templates help cover edge cases (error handling, loading states) but simplify when possible for MVP.

---

### Tools and SDK: APNs, Background Tasks, Keychain + Biometrics

**APNs on iOS:** Use native UserNotifications.

1. Request permission:

```swift
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in }
```

Request only after login or when needed, not at launch.
2. Register for remote notifications: call `UIApplication.shared.registerForRemoteNotifications()` (developer.apple.com). iOS contacts APNs, invoking AppDelegate’s `didRegisterForRemoteNotificationsWithDeviceToken`. In SwiftUI, add AppDelegate via UIApplicationDelegateAdaptor, convert deviceToken → hex, send to backend (`POST /devices/register`).
3. Handle notifications: implement
`userNotificationCenter(didReceive:withCompletionHandler:)` for silent notifications (content-available). Launch background fetch or schedule BGTask. Silent pushes have no UI; call completionHandler(.newData/.noData).

Apple recommends BGAppRefreshTask for background updates—add ID in Info.plist, enable Background Fetch (swiftwithmajid.com). The SwiftUI `.backgroundTask` modifier internally registers BGTaskScheduler handlers (swiftwithmajid.com). Use this modern API—it’s more reliable than old UIApplicationBackgroundFetch.

**Server-side APNs SDK:** Use Python apns2 or forks. Handles HTTP/2, token auth, and both alert/background pushes. For multi-platform abstraction, consider OneSignal or Firebase FCM (uses APNs under the hood). For our single-platform scope, native APNs is simplest. Example:

```python
from apns2.client import APNsClient
from apns2.payload import Payload

payload = Payload(alert=None, sound=None, content_available=True)
client = APNsClient('AuthKey_ABC123.p8', use_sandbox=False, team_id='TEAMID', key_id='KEYID')
client.send_notification(device_token, payload, topic='com.yourapp.bundleid')
```

Sufficient to send a silent push to one device.

________________________________________**Background Tasks and Updates:** In addition to BGTaskScheduler, URLSession background transfers may be needed if large files must be downloaded (not our MVP case). All background activities must be declared to the system: content-available push, background fetch, background processing, background URLSession, or specialized ones (navigation, audio playback, etc.—not applicable here). Apple’s guide *“Choosing Background Strategies for Your App”* outlines this clearly. For our scenario, the best strategy is BGAppRefresh triggered by push. If longer tasks are required (e.g., periodic analytics collection), add a BGProcessingTask (set RequiresExternalPower if heavy and non-urgent).

**Keychain and Biometrics:** Store sensitive data (JWT, refresh tokens, passwords) in the Keychain—a secure store accessible only to your app. In Swift 6 (same as Swift 5), use the Security framework. Configure the key with an access control flag requiring biometric authentication. Do this by adding kSecAttrAccessControl with .userPresence or .biometricCurrentSet flags:

```swift
let accessControl = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    .userPresence,
    nil)!
```

This means the value is device-only, available only with a passcode set, and userPresence requires user authentication (Face ID / Touch ID or passcode) each time it is accessed (andyibanez.com). Then store it:

```swift
let query: [String: Any] = [
  kSecClass: kSecClassGenericPassword,
  kSecAttrAccount: "authToken",
  kSecValueData: tokenData,
  kSecAttrAccessControl: accessControl
]
SecItemAdd(query as CFDictionary, nil)
```

When reading the same item via SecItemCopyMatching, the system automatically shows the Face ID/Touch ID prompt (andyibanez.com). You should not manually invoke LAContext.evaluatePolicy in this case—let Security handle it. This is secure: even on a jailbroken device, the token cannot be retrieved without biometrics. Alternatively, use KeychainAccess (a Swift wrapper supporting AccessControl). Add NSFaceIDUsageDescription to Info.plist, or Face ID access will be blocked (developer.apple.com).

**Biometric Login UX:** On app launch, if the user is already signed in, prompt for Face ID/Touch ID by reading the token from Keychain—Keychain will display “Unlock using Face ID.” Optionally use LocalAuthentication (LAContext) to check biometric availability or add custom fallback. In short: store tokens in Keychain bound to biometrics for best protection with minimal code (andyibanez.com).

**Background Fetch vs Push vs Notifications:** Combine silent push + BGTask for timely background data sync. Local notifications aren’t needed (unless explicitly notifying users, which MVP does not). Biometrics improve security with minimal UX friction (one unlock per launch). All these are Apple-native, well-documented tools. References: [Apple Developer: Background Tasks strategy][5], [Apple: Pushing Background Updates][3], [Apple: Keychain and LocalAuthentication docs][37].

---

### CI/CD for iOS and Backend

**Mobile CI/CD (TestFlight):** As noted, GitHub Actions + fastlane is the de-facto standard. Set up a workflow triggered on main-branch push or manual run. Steps: build iOS (xcodebuild or fastlane gym), run tests (xcodebuild test or fastlane scan), then upload the build. fastlane’s upload_to_testflight (alias pilot) sends the .ipa to TestFlight (medium.com). You’ll need an App Store Connect API key (JSON) stored in repo secrets. Handle code-signing either with automatic signing (Xcode 13+) or fastlane Match (brightinventions.pl). Best practice: keep certificates in a private repo and connect via Match, protected with MATCH_PASSWORD in secrets (brightinventions.pl). Add linting steps—run swiftlint through fastlane plugin or shell to prevent merging style violations.

After successful upload, Apple typically processes builds in 5–15 minutes (longer for new versions due to compliance review). Auto-increment build numbers via fastlane increment_build_number. Notifications: ensure you or testers are alerted (App Store Connect emails or Slack via GitHub Actions Slack Notification). Testers then get the latest build immediately.

**Backend CI/CD:** Add a FastAPI pipeline too. Main stages: run tests (pytest), static analysis (flake8 or ruff—very fast), type-check (mypy), and format (black, isort). Automate via pre-commit hooks and CI. On success—deploy. If using one VPS, configure SSH deploy via GitHub Actions—ready steps exist for copying files or running commands post-push. For production readiness, containerize: write a Dockerfile (FROM python:3.12-slim), build/push image to GHCR or Docker Hub, and update service (docker pull + compose up). On PaaS (Cloud Run, Fly.io), CI deploys automatically (actions for each platform available).

**Code Quality and Alerts:** Integrate GitHub CodeQL for static vulnerability analysis. Track dependency updates with Dependabot (GitHub built-in); CI ensures updates don’t break builds. Optionally add OWASP ZAP or Snyk security scans. DevOps alerts: CI should notify failures—if deploy fails, get notified immediately. GitHub Actions can emit workflow-run events; simplest: email or Sentry release tracking (report deploys and failed releases).

**Release Management:** Use semantic versioning for both app and backend. iOS: each TestFlight build = unique build number; tag important ones (v1.0). Server: version APIs (e.g., /v1) and update changelog on CI deploy. CI/CD reduces human error—automated builds ensure migrations and tests run every release.

**CI/CD Summary**

* Use GitHub Actions for both mobile and backend.
* Automate quality checks: lint, test, format, analyze.
* Zero-effort deploys: fastlane + Actions (iOS), Docker/SSH + Actions (backend).
* Alerts via Slack/email for key events (release success, build failure).

Following these best practices yields a reliable MVP in 2–3 weeks—maintainable by one engineer, delivering fast UI, timely order updates (push ≤ 120 s), and stable backend API (p95 ≤ 300 ms).

**Good luck. 🚀**

---

### Guide for MVP & Scaling of iOS Client “Zariz” (Courier Order Tracker)

Adapted to the current spec, realistic constraints (1 engineer, 1 VPS). Goal: rapid, secure MVP with safe growth.

---

#### Cover

* **Topic:** iOS Best Practices 2025 for “Zariz”
* **Audience:** Mobile/iOS, Backend/API, DevOps
* **Project:** Zariz (retail delivery)
* **Context:** 1 engineer, 2–3 weeks MVP, single VPS (API + Postgres + Reverse proxy), SwiftUI client, geo later, SLA ≥ 99%, API p95 < 300 ms
* **Date:** 2025-10-22
* **Authors:** team@zariz

---
## TL;DR (≤10)

1. **Client architecture:** SwiftUI + MVVM + Clean (modules: Auth/Orders/Notifications), Swift 6 Concurrency (async/await, `@MainActor`, `Sendable`), dependency injection via protocols/factories.
2. **Networking:** `URLSession` + async/await; typed API client, universal retry with exponential backoff + jitter, idempotency via `Idempotency-Key` for `claim` and status updates.
3. **Data/offline:** SwiftData as local cache (DTO → Entity mapping), background sync through silent pushes (`content-available=1`) + `BGTaskScheduler`, polling fallback with backoff.
4. **Status updates:** server—atomic `claim` using transaction/`SELECT … FOR UPDATE SKIP LOCKED`; iOS—double-tap protection (button lock + idempotent request + status re-apply).
5. **Observability:** `OSLog` categories, breadcrumbs and crashes via Sentry; key metrics — p95 list load, success rate of `claim`, latency “push → data applied” ≤ 120 s.
6. **Security/Privacy:** JWT in Keychain, PII minimization, log redaction, ATS, TLS, token protection from logs/crashes; BOLA checks on API.
7. **CI/CD:** GitHub Actions + fastlane (build/test/lint/format/upload-to-TestFlight), auto-symbolication, linters (SwiftLint/SwiftFormat), Danger reports on PRs.
8. **Performance:** target SLOs — cold start < 2 s, memory < 200 MB, list render ≤ 16 ms per frame; profile with Instruments.
9. **Testing:** unit (ViewModel/UseCase), integration (network via `URLProtocol`), UI tests for critical flows (login/list/claim/status change), snapshots.
10. **Roadmap:** v1 — no geo; v2 — geo, user pushes, ETA, analytics, Android.

---

## Landscape 2024–2025

* Swift 6 strict concurrency: `Sendable`, `@MainActor`, actors for state safety → fewer races, better UI responsiveness.
* SwiftData stabilized for simple local caches; Observation/`@Observable` improve SwiftUI reactivity.
* Background Tasks: sync via `BGAppRefreshTask`/`BGProcessingTask` is preferred to persistent sockets.
* APNs: focus on silent pushes for content updates with reasonable battery coalescing.
* iOS 18 / Xcode 16: new performance inspectors, Instruments upgrades, stable async/await support in SDK.

---

## Patterns and When to Apply

**Pattern A — MVP “offline-light” (recommended start)**

* **When:** 1 engineer, 1 VPS, ~100 couriers / 50 stores, SLO “data applied ≤ 120 s.”
* **Steps:** (1) local SwiftData cache; (2) sync via silent push + background task; (3) polling fallback every 2–5 min with backoff.
* **Pros:** simple, predictable, minimal deps; **Cons:** not instant real-time.
* **Later options:** event aggregation, server-priority conflict resolution, VIP-order fast sync.

**Pattern B — “Enhanced Sync” (scaling)**

* **When:** demand for near-real-time, geo/routes/ETA added.
* **Steps:** (1) event-sourcing model extension; (2) fine push/sync prioritization; (3) server deduplication; (4) geo subsystem.
* **Pros:** higher freshness; **Cons:** more complex telemetry and conflict resolution.

---

## Priority 1 — Order Lifecycle and Sync

### Why

Critical UX: courier must see fresh orders, claim, and update status without races or duplicates.

### Scope

Includes order list, details, claim, status update, cache, background sync, polling fallback.
Excludes geo, ETA, chats (v2).

### Solutions

* API: `GET /orders?status=new|claimed`, `POST /orders/{id}/claim` (with `Idempotency-Key`), `POST /orders/{id}/status` (picked_up/delivered).
* Idempotency key = `deviceId:orderId:op:nonce`; server returns last valid result for retries.
* Atomic claim: transaction or `SELECT … FOR UPDATE SKIP LOCKED` prevents double assignment.
* UX: lock claim button during request; retry same key on network failure.

### Client Implementation

ViewModel → UseCase → Repository → APIClient/Store (SwiftData); all layers protocol-based for test mocks.
List: pagination/pull-to-refresh; local first, then diff update from network.
Silent push: on receive → sync relevant orders → apply patch locally → `@Observable` re-renders UI.
Background: `BGAppRefreshTask` every N minutes (with system limits) → diff sync.

### Limits & SLO

p95 “push → UI data” ≤ 120 s; p95 list load ≤ 700 ms (cache + network); claim success ≥ 99.5%.

### Failures & Recovery

Offline → show cache; queue local actions with idempotent replay.
Duplicate claim → server 409/422 with status body; client reconciles UI to server truth.

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

## Priority 2 — Auth and Secure Storage

### Solutions

JWT (access short-lived) + refresh (API); store tokens in Keychain, never log.
Optional biometrics: `LocalAuthentication` for quick re-login.
Secure defaults: ATS only HTTPS; cert-pinning optional later.

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

## Priority 3 — Notifications & Background Updates

### Solutions

Silent APNs (`content-available=1`) to trigger sync; user pushes later.
`BGAppRefreshTask` for periodic sync; avoid persistent sockets.

```swift
BGTaskScheduler.shared.register(forTaskWithIdentifier: "app.zariz.refresh", using: nil) { task in
  Task { await SyncService.shared.refresh(); task.setTaskCompleted(success: true) }
}

let request = BGAppRefreshTaskRequest(identifier: "app.zariz.refresh")
request.earliestBeginDate = Date(timeIntervalSinceNow: 15*60)
try? BGTaskScheduler.shared.submit(request)
```

---

## Domain Practices

1. **Code Style & Concurrency:** Swift 6 Concurrency (`Sendable`, `nonisolated`, `@MainActor`), actors for safe resources; hierarchy of `AppError`; linters (SwiftLint/SwiftFormat, pre-commit).
2. **API/Module Design:** Layers `Domain`/`Data`/`UI`; protocol DI; OpenAPI 3.1 + optional SDK gen.
3. **Data & State:** SwiftData entities `Order`/`Store`/`User`/`StatusEvent`; TTL/ETag cache; server-first merge.
4. **Security:** Keychain for tokens; no logs; symbolicated crash redaction; no UserDefaults for PII.
5. **Privacy & Compliance:** Privacy Manifest if needed; no ATT in MVP; data-deletion on request.
6. **Performance & Cost:** cold start < 2 s; frame ≤ 16 ms; memory < 200 MB; budget network bytes; profile with Instruments.
7. **Observability:** `OSLog` categories (auth/orders/sync/network); Sentry for crashes/breadcrumbs.
8. **CI/CD:** GitHub Actions matrix (iOS 17/18); steps build/test/lint/format/upload via fastlane; auto code-signing.
9. **Testing:** Unit (ViewModel/UseCase), Integration (URLProtocol stubs 401/409/5xx + retries), UI (XCUITest login→list→claim→status), snapshots.
10. **Docs:** short ADRs, layer diagram, debug/prod flags guide, release checklists.

---

## Observability & SLOs

**Key Metrics (client)**
Crash-free users ≥ 99.5%.
p95 list load ≤ 700 ms; p95 “push → UI” ≤ 120 s.
Claim errors < 0.5%; >2 retries → log alert.
Active couriers/hour, offline actions ratio.

**Alerting**
Sentry: crash spikes, network/auth errors.
Backend monitoring: API SLA, push queue, event processing rate.

| Surface    | SLI                    | Target  | Window | Notes                 |
| ---------- | ---------------------- | ------- | ------ | --------------------- |
| Order list | p95 launch → list time | ≤ 2 s   | 7/30 d | cold start            |
| Sync       | p95 push → UI data     | ≤ 120 s | 7/30 d | silent push + BGTask  |
| Claim      | success rate           | ≥ 99.5% | 7/30 d | idempotency + retries |

---

## Reliability

Retries with exponential backoff + jitter; cancel on view exit.
All mutations idempotent; client stores last result.
Kill-switches/feature-flags for risky features; fallback to cache on network failures.

---

## Performance & Budget

Minimize SwiftUI re-renders (`EquatableView`, memoized formatters/dates).
Compress/trim network responses; use ETag/If-None-Match.

---

## Security & Privacy

Threats: token theft, MITM, PII leaks via logs.
Controls: Keychain, ATS, no sensitive logs, Sentry redaction, token rotation on compromise.

---

## Testing Strategy

Smoke E2E on staging (fake orders).
DTO contract tests vs OpenAPI.
Mini load test (100 parallel claims).

---

## Risks & Trade-offs

| Risk                     | Impact | Probability | Mitigation                                            |
| ------------------------ | ------ | ----------- | ----------------------------------------------------- |
| Sync delay > 120 s       | Medium | Medium      | priority push for active orders; aggressive BGRefresh |
| Duplicate claim          | High   | Low         | DB atomicity; idempotent client                       |
| Crashes on older devices | Medium | Low         | test on iOS 17/18; crash reports; hotfixes            |

---

## Recommendations & Roadmap

**MVP (2–3 weeks)** — Auth, order list/details/claim/status; SwiftData cache; background sync; Sentry/OSLog; CI (build/test/lint/TF).
**Hardening & v2** — Geo/routes, user pushes, ETA, advanced analytics, Android client.

---

## Appendices — Snippets

**OSLog Categories**

```swift
import OSLog
let log = Logger(subsystem: "app.zariz", category: "orders")
log.info("Order list loaded: count=\(count)")
```

**Typed URLSession Client**

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

**BG Task Timing**

```swift
// Schedule responsibly; system coalesces automatically
request.earliestBeginDate = Date(timeIntervalSinceNow: 15*60)
```

---

## Reading List (2024–2025 annotated)

| Title                                               | Date | Type  | Essence                                      | Relevance |
| --------------------------------------------------- | ---- | ----- | -------------------------------------------- | --------- |
| Choosing Background Strategies for Your App (Apple) | 2024 | Doc   | Silent push + BGTasks vs sockets             | 10/10     |
| Pushing Background Updates (Apple)                  | 2024 | Doc   | `content-available=1`, battery limits        | 10/10     |
| SwiftData Documentation (Apple)                     | 2025 | Doc   | Local cache, models/migrations               | 9/10      |
| What’s New in Swift Concurrency (WWDC)              | 2024 | Talk  | Strict concurrency, `Sendable`, `@MainActor` | 9/10      |
| OWASP Mobile Top-10 (2023)                          | 2023 | Std   | Mobile threats / defenses                    | 8/10      |
| URLSession Best Practices (Apple)                   | 2024 | Guide | Async/await, cache, TLS                      | 9/10      |
| Sentry iOS SDK                                      | 2025 | Doc   | Crashes/breadcrumbs/redaction                | 8/10      |

---

## Checklists

**Implementation**

* [ ] Layered architecture + DI
* [ ] Typed API client + retries
* [ ] SwiftData cache + background sync

**Security/Privacy**

* [ ] JWT in Keychain, no logs
* [ ]


Logs redacted

*  [ ] ATS/TLS enforced

**Observability**

* [ ] OSLog categories
* [ ] Sentry integrated
* [ ] SLO dashboard

**CI/CD & Ops**

* [ ] Actions + fastlane
* [ ] Linters/formatters
* [ ] TestFlight releases

**Release Readiness**

* [ ] ADRs/diagram current
* [ ] Runbook “sync/claim failures”
* [ ] KPI dashboard

---

## Changelog

* 2025-10-22: Initial version, adapted for Zariz.
