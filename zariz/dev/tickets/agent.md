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


Start with /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/open/TICKET-22_Web_Admin_Secure_Login_and_Session_Guards.md:


~/IdeaProjects/ios/zariz (main) ❯ cat /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/open/TICKET-22_Web_Admin_Secure_Login_and_Session_Guards.md
Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-22] Web Admin — Secure Login (admin‑only) and Session Guards

Goal
- Deliver a production-ready authentication experience for the admin web panel (admin‑only) using the new backend contracts, with protected routes, refresh handling, and logout.

Context
- `/pages/login.tsx` currently sends `{subject, role}` to the stub login endpoint; any input succeeds. There is no password field, CSRF protection, or route guard. Orders pages assume a token exists in `localStorage`.
- Backend will provide real JWT + refresh tokens (TICKET-21). Only system admin can log into web admin; stores/couriers не получают доступ к админке.

Scope
1) Login UX & validation (admin‑only)
   - Replace subject/role inputs with email/phone + password fields, inline validation, and error messaging (translated strings).
   - No self‑service, no password reset UI — только подсказка «обратитесь к администратору Zariz».
2) Session management
   - Move auth handling to Next.js API route `/api/auth/login` that proxies to backend, sets `httpOnly`, `Secure`, `SameSite=Strict` cookies for refresh token, stores access token in memory (React context).
   - Implement `/api/auth/refresh` and `/api/auth/logout`, rotate tokens, clear cookies.
   - Add `AuthProvider` React context to wrap pages, automatically refresh when token expiry <2 minutes (with exponential backoff and jitter).
3) Route guards & RBAC
   - Implement `withAuth` HOC / middleware to redirect unauthenticated users to `/login`.
   - Verify `role=admin` in JWT; otherwise force logout.
4) Security & observability
   - Sanitize logs, never store tokens in localStorage (dev‑only fallback off by default).
5) Tests & docs
   - Playwright E2E: admin login success, wrong password, session expiry (refresh) across navigation.
   - Jest/unit tests for `AuthProvider` and API routes with mocked fetch.
   - Update `web-admin/README.md` with setup, env vars (`NEXT_PUBLIC_API_BASE`, `AUTH_COOKIE_NAME`).

Plan
1. Build `libs/authClient.ts` with `login`, `refresh`, `logout`, storing access token in SWR/React state.
2. Create Next.js API routes using `fetch` to backend; ensure proper error propagation and cookie serialization (`cookie` npm package).
3. Rewrite `/pages/login.tsx` UI with formik/react-hook-form (or controlled state) + password field; disable submit while pending.
4. Add `_app.tsx` provider to wrap pages in `AuthProvider`; guard getServerSideProps to redirect when unauthenticated.
5. Update `orders` and other pages to consume `AuthContext`, handle store selection from JWT claim.
6. Implement tests: Jest (using msw) for API routes; Playwright for login + refresh; update CI workflow to run `yarn test` and `yarn test:e2e`.
7. Document local dev flow and sample credentials provided by TICKET-21 CLI.

Verification
- `cd zariz/web-admin && yarn test`.
- `yarn test:e2e --project=chromium --grep "@auth"` for Playwright suite.
- Manual: start backend with seeded user, run `yarn dev`, log in, navigate across pages, refresh browser (session persists), logout clears cookies.

File references / Changes
- `zariz/web-admin/pages/login.tsx`, `_app.tsx`, `_middleware.ts` (or Next.js middleware)
- `zariz/web-admin/pages/api/auth/login.ts`, `refresh.ts`, `logout.ts` (new)
- `zariz/web-admin/libs/api.ts` (attach bearer token from context), `libs/authClient.ts` (new)
- `zariz/web-admin/context/AuthContext.tsx` (new)
- `zariz/web-admin/tests/unit/authClient.test.ts`, `pages/api/auth/login.test.ts`
- `zariz/web-admin/tests/e2e/auth.spec.ts`
- `zariz/web-admin/README.md`

Notes
- Cookies must be prefixed with `__Host-` in production (HTTPS) to mitigate CSRF.
- Align error strings with backend (`code`, `message`); surface `password_expired` cases with actionable UI.
~/IdeaProjects/ios/zariz (main) ❯ 




