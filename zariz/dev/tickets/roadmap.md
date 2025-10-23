# Zariz Roadmap

Track progress for the iOS app, backend, and store web panel. Update this file by marking finished items with [x]. Each ticket refers back here; please mark the matching line when complete.

Repository: /Users/sasha/IdeaProjects/ios

## Time Estimates (Solo + AI)

Assumptions
- 1 developer using AI assistants; 6–7 focused hours/day.
- Reuse from references: DeliveryApp-iOS, Swift-DeliveryApp, food-delivery-ios-app, deliver-backend, next-delivery.
- MVP scope: no geolocation; SSE for web; silent pushes on iOS.

Scenario Timelines (calendar working days)
- Optimistic: 12–13 days (≈2.5 weeks). Few integration hiccups, fast provisioning.
- Realistic: 15–17 days (≈3–3.5 weeks). Normal certs/provisioning cycles and minor refactors.
- Conservative: 20–22 days (≈4–4.5 weeks). Delays with APNs/TestFlight, infra and review loops.

Stage Estimates (O / R / C)
- Stage A — Foundation: 3.5 / 5 / 7 days
- Stage B — iOS App: 4 / 5 / 7 days
- Stage C — Store Web Panel: 2.5 / 3 / 4 days
- Stage D — Quality & Release: 2.5 / 3 / 4 days

Risk & Accelerator Factors
- Accelerators: copy module layout, FaceID flow, and SwiftUI screens from DeliveryApp-iOS/Swift-DeliveryApp; reuse Next admin patterns; strict scope; SSE over WS.
- Risks: APNs keys/profiles, TestFlight/App Store delays, CI signing, docker network/CORS, idempotency edge cases, atomic-claim race tests, domain/TLS setup.
- Mitigations: parallelize paperwork (Apple dev, APNs) with Stage A coding; stub notifications; enable polling fallback; keep OpenAPI-driven contracts; small PRs.

Per-ticket Estimate Hints (realistic unless noted)
- 1: 0.5–1d, 2: 1–1.5d, 3: 2–3d, 4: 1.5–2d, 5: 1–1.5d
- 6: 0.5–1d, 7: 1–1.5d, 8: 2–3d, 9: 1d
- 10: 1–1.5d, 11: 0.5–1d, 12: 1–1.5d
- 13: 1–1.5d, 14: 1d, 15: 1–1.5d

Progress: mark done items with [x] and adjust the above ETA line-by-line as you go.

## Stage A — Foundation

 - [x] 1. Monorepo structure, tooling, Docker baseline
 - [x] 2. Backend scaffold (FastAPI, SQLAlchemy, Alembic, JWT)
 - [x] 3. Core APIs: auth + orders CRUD/idempotency _(TICKET-21 complete)_
 - [x] 4. Notifications: APNs worker, device registry, SSE for web
 - [x] 5. CI/CD + Deploy: Actions, Docker images, Compose/Nginx

## Stage B — iOS App

 - [x] 6. iOS project bootstrap (SwiftUI, modules, SwiftData models)
 - [ ] 7. iOS auth flow + Keychain _(blocked by TICKET-24)_
 - [x] 8. Orders UI (list/detail), claim, status updates, offline cache, BG tasks + silent push
 - [x] 9. iOS CI/TestFlight (fastlane, Actions, testers)

## Stage C — Store Web Panel

 - [x] 10. Web panel scaffold (Next.js/TS), auth, routes _(requires TICKET-22)_
 - [ ] 11. RBAC + security hardening _(needs TICKET-21 & TICKET-22)_
 - [x] 12. Realtime status (SSE), list filters, UX polish

## Stage D — Quality & Release

 - [x] 13. E2E tests (Playwright), fixtures, contract tests
 - [x] 14. Observability (Otel, Sentry), docs, runbooks
- [ ] 15. Release & handover (App Store/TestFlight, server backup)

Notes:
- Keep MVP scope: no geolocation. Optimize for reliability and clarity.
- Ensure OpenAPI spec drives client generation and contract tests.
- Agent automation: default Execute mode (see `zariz/dev/tickets/agent.md`). Agent loops through lowest-numbered open tickets; set `zariz/dev/tickets/.mode` to `plan` to pause implementation and stay in plan/update-only.
