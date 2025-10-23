# Zariz — Admin Web Panel (Next.js + TypeScript)

Secure admin-only panel with JWT auth, httpOnly refresh cookie, and in-memory access tokens.

## Prerequisites
- Node 18+
- Yarn
- Backend running on `http://localhost:8000` (default) with seeded admin user

## Environment
Create `.env.local` and set as needed:

```
NEXT_PUBLIC_API_BASE=http://localhost:8000/v1
# Name for refresh cookie; in prod will be prefixed with __Host-
AUTH_COOKIE_NAME=zariz_refresh
```

Notes:
- In production, the refresh cookie is set as `__Host-zariz_refresh` (httpOnly, Secure, SameSite=Strict, Path=/).
- Access token is stored in memory only (never in localStorage). Refresh rotates automatically when <2 minutes left.

## Install & Run
```
yarn
yarn dev
```

## Tests
- Unit (Jest): `yarn test`
- E2E (Playwright): `E2E_BACKEND=1 E2E_ADMIN_ID=email E2E_ADMIN_PWD=pwd yarn test:e2e --project=chromium --grep "@auth"`

## Auth Flow Summary
- `POST /api/auth/login` → proxies to backend `/v1/auth/login_password`, sets httpOnly refresh cookie; returns `access_token` to client.
- `POST /api/auth/refresh` → rotates refresh cookie and returns a new `access_token`.
- `POST /api/auth/logout` → revokes session and clears cookie.
- Client stores access token in memory (`libs/authClient.ts`), schedules auto-refresh, and enforces `role=admin`.

## Security
- CSRF: refresh token is `httpOnly; Secure; SameSite=Strict; Path=/`.
- No tokens in localStorage; logs sanitized; do not print tokens.

## Admin Pages
- Stores: `/stores`, detail `/stores/[id]`, creation `/stores/new`.
- Couriers: `/couriers`, detail `/couriers/[id]`, creation `/couriers/new`.
- Each detail page includes a Credentials block to change login (email/phone) and set a temporary password.
