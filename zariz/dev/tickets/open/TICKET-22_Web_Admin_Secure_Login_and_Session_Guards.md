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
