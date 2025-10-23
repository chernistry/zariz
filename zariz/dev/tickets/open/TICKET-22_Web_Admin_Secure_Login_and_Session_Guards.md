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

---

Analysis
- Current web-admin uses a stub login in `pages/login.tsx` posting `{subject, role}` to `/v1/auth/login` and stores the access token in `localStorage`. Route guards (`libs/withAuth.tsx`) also rely on `localStorage`. This violates requirements: no tokens in localStorage, admin-only access, refresh rotation, and proper cookie scoping.
- Backend provides proper endpoints: `POST /v1/auth/login_password` returns `{access_token, refresh_token}`, `POST /v1/auth/refresh` rotates both, and `POST /v1/auth/logout` revokes the session. JWT contains `role` and possibly `store_ids` claims; we must enforce `role=admin` for web-admin.
- Repo already has a basic `contexts/auth` but it currently writes a cookie named `token` and keeps token in state; pages still fetch the token from `localStorage`. We will centralize auth to an `authClient` (in-memory access token) and an `AuthProvider` handling refresh with exponential backoff and jitter.

Plan (Execute)
1) Add in-memory auth client
   - Create `zariz/web-admin/libs/authClient.ts` exporting: `login(identifier, password)`, `refresh()`, `logout()`, `getAccessToken()`, `subscribe(cb)`, and small `parseJwt()`.
   - Store only the short-lived access token in memory; schedule auto-refresh when `exp - now < 120s` with exponential backoff (max 60s) and jitter.
2) Next.js API proxy routes
   - Add `pages/api/auth/login.ts`: proxy to `${NEXT_PUBLIC_API_BASE}/auth/login_password`, set httpOnly `Secure` `SameSite=Strict` cookie with refresh token. Cookie name from `AUTH_COOKIE_NAME` (default `__Host-zariz_refresh` in prod; `zariz_refresh` in dev). Return only `{access_token}` to client.
   - Add `pages/api/auth/refresh.ts`: read refresh cookie, proxy to backend `/auth/refresh`, rotate cookie, return `{access_token}`. 401 when missing/invalid.
   - Add `pages/api/auth/logout.ts`: read cookie, proxy to backend `/auth/logout`, clear cookie.
3) Auth provider and guards
   - Extend `contexts/auth` into a full `AuthProvider`: initialize from empty state, expose `token`, `user`, `login`, `logout`. Verify `role=admin` from JWT on every token set; otherwise force logout.
   - Update `libs/withAuth.tsx` to redirect unauthenticated users (no in-memory token) to `/login` and to re-check on token changes.
4) Refactor API and pages
   - Update `libs/api.ts` to attach `Authorization: Bearer <in-memory token>` instead of `localStorage`.
   - Rewrite `pages/login.tsx` to email/phone + password form, calling `/api/auth/login`. Show inline validation and errors; no role selector.
   - Replace all `localStorage` calls (logout, guards) with context/authClient usage. Update `orders` pages’ logout action to call `/api/auth/logout` and clear context.
5) Tests
   - Add Jest unit tests: `tests/unit/authClient.test.ts` (timer/backoff + admin role enforcement) and minimal API route tests with mocked backend fetch.
   - Add Playwright E2E `tests/e2e/auth.spec.ts` covering: admin login success, wrong password shows error, refresh across navigation (mark as "execute later" if backend seeds are absent at CI runtime).
6) Docs
   - Update `web-admin/README.md` with setup, env vars, and how to run tests. Document cookie name and security notes.

Verification Steps (to run now)
- Build: `cd zariz/web-admin && yarn && yarn build`.
- Unit tests: `yarn test`.
- E2E: `yarn test:e2e --project=chromium --grep "@auth"` (execute later if backend not running).

Risk/Notes
- If backend is not running or seeded admin is missing, E2E will be deferred; unit tests run with mocked fetch.
- Ensure CORS is not involved since Next API proxies server-to-server; only access token returns to browser.

Implementation Summary
- Added in-memory auth client: `zariz/web-admin/libs/authClient.ts` with login/refresh/logout, token subscriptions, and admin-only enforcement.
- Added Next.js API routes:
  - `zariz/web-admin/pages/api/auth/login.ts` → proxies to backend `/v1/auth/login_password`, sets httpOnly refresh cookie, returns access token.
  - `zariz/web-admin/pages/api/auth/refresh.ts` → rotates refresh cookie, returns access token.
  - `zariz/web-admin/pages/api/auth/logout.ts` → revokes and clears cookie.
- Refactored client:
  - `zariz/web-admin/libs/api.ts` now attaches `Authorization` from in-memory token.
  - `zariz/web-admin/libs/withAuth.tsx` now guards via in-memory token and subscribes to auth changes.
  - `zariz/web-admin/pages/login.tsx` replaced with email/phone + password, error messaging, pending state.
  - `zariz/web-admin/pages/index.tsx` and `zariz/web-admin/pages/orders*.tsx` updated to remove `localStorage` usage; logout calls `/api/auth/logout`.
  - `zariz/web-admin/contexts/auth/*` extended to subscribe to `authClient` and bootstrap via `/api/auth/refresh`.
- Tests:
  - Jest config `zariz/web-admin/jest.config.js`; devDeps added.
  - Unit tests: `zariz/web-admin/tests/unit/authClient.test.ts`, `zariz/web-admin/tests/unit/api_login.test.ts`.
  - E2E skeleton: `zariz/web-admin/tests/e2e/auth.spec.ts` (skips unless `E2E_BACKEND=1`).
- Docs: `zariz/web-admin/README.md` updated with setup, env vars, and test commands.

How to Run
- Install deps: `cd zariz/web-admin && yarn`
- Build: `yarn build`
- Unit tests: `yarn test`
- E2E (when backend is running with seeded admin):
  `E2E_BACKEND=1 E2E_ADMIN_ID=admin@example.com E2E_ADMIN_PWD=secret yarn test:e2e --project=chromium --grep "@auth"`

Changed Paths
- libs: `zariz/web-admin/libs/authClient.ts`, `zariz/web-admin/libs/api.ts`, `zariz/web-admin/libs/withAuth.tsx`
- pages: `zariz/web-admin/pages/login.tsx`, `zariz/web-admin/pages/index.tsx`, `zariz/web-admin/pages/orders.tsx`, `zariz/web-admin/pages/orders/new.tsx`
- API routes: `zariz/web-admin/pages/api/auth/login.ts`, `zariz/web-admin/pages/api/auth/refresh.ts`, `zariz/web-admin/pages/api/auth/logout.ts`
- context: `zariz/web-admin/contexts/auth/*`
- tests: `zariz/web-admin/tests/unit/*`, `zariz/web-admin/tests/e2e/auth.spec.ts`
- docs/config: `zariz/web-admin/README.md`, `zariz/web-admin/jest.config.js`, `zariz/web-admin/package.json`

Verification Results
- Build: `yarn build` — successful.
- Unit tests: `yarn test` — passing (2 suites).
- E2E: added but skipped by default; run later with backend.
