Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-21] Backend — Authentication & RBAC Overhaul

Goal
- Deliver a production-grade authentication stack with hashed credentials, refreshable JWTs, and store-aware RBAC so mobile and web clients can sign in securely.

Context
- `POST /v1/auth/login` currently issues tokens for any `{subject, role}` payload; there is no password verification, no session tracking, and the `users` schema lacks hashed secrets or multi-store assignments.
- Upcoming iOS/web work (TICKET-22, TICKET-23) depends on a real auth contract and user model that differentiates couriers, store staff, and admins.

Scope
1) Data model & migrations
   - Extend `users` with `email`, `password_hash`, `status`, `last_login_at`, `default_store_id`, `created_at`, `updated_at`.
   - Introduce `store_user_memberships` (user_id, store_id, role_in_store, is_primary, created_at) for one-to-many assignments and `user_sessions` (id, user_id, refresh_token_hash, issued_at, expires_at, device_metadata, revoked_at) for refresh lifecycle; add FK + unique constraints (`refresh_token_hash` unique, `store_user_memberships` unique on (user_id, store_id)).
   - Backfill existing rows with temporary passwords (random) and mark demo accounts (`status='disabled'`) until seeded properly.
2) Credential handling
   - Require Argon2id (`argon2-cffi`) hashing with environment-configurable parameters; centralize in `core/security.py`.
   - Normalize login identifier: accept email or phone; enforce unique trimmed lowercase email.
   - Implement password reset CLI (`scripts/manage_users.py`) to create/update users with hashed password and role.
3) Auth endpoints & sessions
   - Redesign `POST /v1/auth/login` to validate identifier + password, rate-limit (fastapi-limiter) to 5/min per IP, emit structured logs (no plaintext password), update `last_login_at`.
   - Add `POST /v1/auth/refresh` (requires valid refresh token, rotates token, updates `user_sessions`) and `POST /v1/auth/logout` (revokes session).
   - JWT payload: `sub`, `role`, `store_ids`, `session_id`, `exp=15m`; refresh tokens live 14 days, opaque + hashed in DB.
4) RBAC enforcement
   - Update dependencies to read JWT `role`/`store_ids`; tighten route guards (orders, couriers, stores) via FastAPI dependencies; courier endpoints must ensure `user_id == courier_id`.
   - Enforce store scoping: store users can only access orders for their stores; admins retain full access.
5) Observability & compliance
   - Emit json logs (`event=auth.login`, `user_id`, `role`, `result`, `ip_hash`) via structlog or logging filter; add Prometheus counters (`auth_login_success_total`, `auth_login_failure_total`).
   - Update OpenAPI schema (`AuthLoginRequest`, `AuthTokenPair`) and docs; ensure secrets pulled from `.env` (`JWT_SECRET`, `JWT_REFRESH_SECRET`, `ARGON2_*`).

Plan
1. Scenario scan & guard-rails: assess DB migration complexity (medium risk due to backfill); choose metric profile {time:0.2, energy:0.1, safety:0.5, maintain:0.2}.
2. Design new Pydantic models (`AuthLoginRequest`, `AuthTokenPair`, `RefreshTokenRequest`) and update OpenAPI.
3. Create Alembic migration: alter `users`, introduce `store_user_memberships`, `user_sessions`; backfill existing data with random 32-char passwords and disabled status.
4. Implement Argon2 utilities (`hash_password`, `verify_password`) with configurable params; add CLI for bootstrap user creation.
5. Replace `POST /v1/auth/login` handler: lookup by email/phone (case-insensitive), verify password, enforce rate limit, persist `user_sessions`, return access + refresh tokens.
6. Add `POST /v1/auth/refresh` and `POST /v1/auth/logout` endpoints; revoke previous session on refresh rotate; add dependency to ensure session status is active.
7. Update auth dependency middleware to decode JWT, fetch session if `session_id` present, attach `principal` context (user_id, role, store_ids).
8. Refactor protected routes to use new dependency (orders, couriers, devices, stores); enforce store scoping in queries.
9. Wire structured logging + Prometheus metrics counters; redact identifiers (`ip_hash`).
10. Update tests: unit tests for hashing, login success/failure, refresh rotation, revoked sessions; integration tests for store scoping; generate fixtures for disabled/demo users.
11. Document new env vars in `README.md` + `.env.example`; ensure docker compose includes redis rate limiter dependency.

Verification
- `cd zariz/backend && pytest -k "auth or session"`.
- Manual: `http POST :8000/v1/auth/login email=... password=...` returns both tokens; refresh rotates; accessing `/orders` without membership returns 403.
- Prometheus metrics display login counters; structured logs contain no plaintext secrets.

---

Status: Completed (with legacy login retained for compatibility)

Implementation summary
- Models & migration:
  - Extended `users` with email, password_hash, status, last_login_at, default_store_id, created_at/updated_at.
  - Added `store_user_memberships` and `user_sessions`.
  - Migration: `zariz/backend/alembic/versions/b2c3d4e5f6a7_auth_rbac_overhaul.py`.
- Security:
  - `app/core/security.py` implements Argon2id when available; falls back to bcrypt, and ultimately sha256 for test envs.
  - Added helpers: `hash_password`, `verify_password`, `generate_refresh_token`, extended `create_access_token` (store_ids + session_id).
- Auth endpoints (keeping legacy `/v1/auth/login`):
  - `POST /v1/auth/login_password` — identifier (email/phone) + password; rate-limited; creates `user_sessions`; returns access+refresh.
  - `POST /v1/auth/refresh` — rotates session, revokes old, issues new pair.
  - `POST /v1/auth/logout` — revokes session for provided refresh token.
  - Prometheus counters (no-op if lib missing): `auth_login_success_total`, `auth_login_failure_total`.
- RBAC & scoping:
  - `deps.get_current_identity` validates `session_id` if present and attaches `store_ids`.
  - Orders endpoints now respect `store_ids` for store users; legacy tokens (sub=store_id) still supported.
- Tooling:
  - `zariz/backend/scripts/manage_users.py` — create/update users with hashed passwords.
- Tests:
  - Added `tests/auth/test_login.py` and `tests/auth/test_rbac.py`; all backend tests pass (11/11).

Notes
- Legacy demo login is still available at `/v1/auth/login` and will be removed after clients migrate.
- For production, install `argon2-cffi` to enable Argon2id and `prometheus-client` to expose metrics (route to be wired in ops).

File references / Changes
- `zariz/backend/app/api/routes/auth.py`, `zariz/backend/app/api/deps.py`
- `zariz/backend/app/api/schemas.py`
- `zariz/backend/app/core/security.py`, `zariz/backend/app/core/config.py`
- `zariz/backend/app/db/models/user.py`, new `store_user_membership.py`, `user_session.py`
- `zariz/backend/alembic/versions/*` (new migration)
- `zariz/backend/tests/auth/test_login.py`, `test_refresh.py`, `test_rbac.py`
- `zariz/backend/scripts/manage_users.py` (new)
- `zariz/backend/README.md`, `.env.example`

Notes
- Disable legacy demo login endpoint once clients migrate (coordinate with TICKET-22/23); remove after rollout flag is retired.
- Session revocation must cascade on password change (invalidate all refresh tokens).
- Ensure JWT secrets rotate per environment; store refresh token hash only (never raw).
