# Agent Execution Protocol — Zariz (iOS + Backend + Web)

## Objective
Execute Zariz MVP tickets with precision and minimal friction, using the agreed stack:
- iOS app: SwiftUI + MVVM, Swift 6, SwiftData for cache, Keychain with biometrics.
- Backend: FastAPI (Python 3.12), SQLAlchemy + Alembic, JWT auth, PostgreSQL.
- Store web panel: Next.js + TypeScript.
Prefer verification‑driven delivery: analyze → plan → implement → verify → self‑critique → document (default Execute mode).

Modes & Triggers
- Execute (default): analyze → plan → implement → verify → document for each ticket.
- Plan/Update only: if the user explicitly says “plan/update only”, or `zariz/dev/tickets/.mode` contains `plan`, or env `ZARIZ_AGENT_MODE=plan`.
Switching modes: change `.mode` or say it explicitly in chat. When in Plan mode, only edit tickets/docs and propose patches; do not write code.

## Primary References (allowed to copy)
We have full rights to reuse these. Prefer selective, high‑quality reuse:
- `zariz/references/DeliveryApp-iOS` (modules: DesignSystem, Core, Networking, Persistence, Coordinator, Analytics; Auth feature)
- `zariz/references/Swift-DeliveryApp` (SwiftUI views/layout patterns)
- `zariz/references/deliver-backend` (modular backend structure, RBAC patterns, Prisma schema reference)
- `zariz/references/next-delivery` (Next.js layout/components/contexts)
- `zariz/references/food-delivery-ios-app` (push event flow ideas)

## Read First
- `zariz/dev/tickets/coding_rules.md` (policies, MCDM, no heuristics, policy dir constraints)
- `zariz/dev/tech_task.md` (functional scope and acceptance)
- `zariz/dev/best_practices.md` (stack practices and non‑functional targets)
- `zariz/dev/tickets/roadmap.md` (stages, estimates)

## Ticket Workflow
1) Selection
- Pick the lowest numbered open ticket in `zariz/dev/tickets/open`.
- If the user says “plan/update only” or mode is Plan, do not run code; update tickets with explicit copy/move/integrate instructions.

2) Analysis (inside the ticket)
- Restate requirements and acceptance criteria.
- Note reference components to reuse (concrete paths). Flag mismatches vs. best_practices and adapt.

3) Plan (inside the ticket)
- List precise file/folder operations (e.g., `cp -R` from reference to destination), renames, and integration points (imports, module links, env vars).
- Include verification steps (build/test/smoke) and execute them by default in Execute mode. If external secrets/infra are missing or mode is Plan, mark them “execute later”.

4) Implementation
- Backend: FastAPI with typed Pydantic models, atomic claim via single UPDATE, idempotency for writes, OpenAPI docs.
- iOS: SwiftUI + SwiftData offline cache, URLSession async/await, Keychain AccessControl with biometrics.
- Web: Next.js pages for login/orders/new; SSE client for realtime.

5) Quality Gates
- Backend: pytest green, ruff/black/mypy clean; `/v1/*` endpoints behave; 409 on conflicting claim; CORS allowlist; rate limits on writes.
- iOS: compiles iOS 17+, Keychain read evokes biometrics; background task registered; silent push handler stubbed.
- Web: pages render; auth redirect if no token; SSE updates list on order events.
- Observability: JSON logs; OTel instrumentation hooks available; optional Sentry DSN.
- Security: JWT roles enforced; BOLA checks; no secrets in logs; HTTPS when in prod.

6) Documentation
- Update the ticket with exact paths changed, commands to run, and how to verify.
- Mark progress in `zariz/dev/tickets/roadmap.md` (change [ ] → [x]).

7) Committing Changes
- After completing each ticket, commit your changes with a meaningful commit message that explains what was done.
- Commit messages should be in imperative mood, concise but descriptive (e.g., "Implement user login with JWT authentication", "Add order tracking UI in SwiftUI").
- Move completed tickets from `zariz/dev/tickets/open` to `zariz/dev/tickets/closed` directory.

Notes for Codex CLI/CI harnesses
- If the environment forbids `git commit` or moving files, still implement and verify. Report a summary and leave files modified; skip the commit/move step.

## Agent Loop
- Start with the lowest-numbered ticket in `zariz/dev/tickets/open`.
- For each ticket (in Execute mode): analyze → plan → implement → verify → document.
- On completion: update `zariz/dev/tickets/roadmap.md` ([ ] → [x]), commit/move the ticket to `zariz/dev/tickets/closed` when allowed, then continue with the next ticket until none remain.

## Conventions
- Paths are relative to repo root. Keep changes minimal and scoped to the ticket.
- Respect `coding_rules.md` (no hardcoded policies; load from `zariz/dev/policies` via `ZARIZ_POLICY_DIR`).
- Prefer async I/O with explicit timeouts; propagate cancellations.
- Use `apply_patch` for code changes; add commands/instructions in tickets. Use `update_plan` for multi‑step tasks.
- Before destructive changes, capture backups/notes in the ticket.

## Stop Rules
- Ambiguity beyond the MVP: propose 1–2 safe options in the ticket and pause for confirmation.
- Non‑MVP features (geolocation, advanced analytics): defer to backlog unless explicitly requested.


Now go and start executing tickets in /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/open


Start with /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/open/TICKET-22_Web_Admin_Secure_Login_and_Session_Guards.md