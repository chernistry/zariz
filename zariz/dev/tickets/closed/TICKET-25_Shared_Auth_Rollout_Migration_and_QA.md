Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-25] Shared — Auth Rollout, Migration, and QA

Goal
- Coordinate backend, iOS, and web authentication rollout with migrations, seed data, documentation, and cross-platform verification to ensure a smooth transition to the new secure auth stack.

Context
- TICKET-21/22/23/24 introduce breaking changes (password login, refresh tokens, store-scoped RBAC). We need a controlled migration path, seed accounts, CI coverage, and release checklist before enabling auth in production/TestFlight.

Scope
1) Migration planning
   - Author `docs/auth-migration.md` describing cutover steps, rollback, and timeline; include comms template for pilot stores/couriers.
   - Prepare Alembic migration ordering (deploy schema first, seed users, deploy services, flip feature flag).
2) Seed data & environments
   - Provide `scripts/seed_auth.py` (or extend existing) to create sample admin, store manager, courier with known demo passwords for staging.
   - Update docker-compose to add Redis (rate limiting) and ensure env vars for JWT secrets, Argon2 params, token TTLs.
   - Populate `.env.example` for backend, iOS `.xcconfig`, and web `.env.local.example` with new auth settings.
3) Feature flags & rollout
   - Introduce `AUTH_MODE=strict|legacy` in backend config; when `legacy`, accept existing `{subject, role}` flow for automated tests until clients upgraded; default to `strict` in staging/prod.
   - Add iOS compile-time flag `AUTH_DEMO_ENABLED` to hide demo toggle in production builds.
4) QA & regression suite
   - Update Postman/OpenAPI contract tests to cover login, refresh, logout (positive/negative).
   - Add end-to-end smoke script (`scripts/smoke_auth.sh`) that logs in via curl, hits orders endpoint, validates 401 after logout.
   - Ensure CI pipelines (backend, iOS, web) run new auth tests; update GitHub Actions to inject seeded credentials.
5) Documentation & support
   - Refresh onboarding guides for stores/couriers with login instructions, password requirements, reset flow.
   - Add runbook entry for locking/banning users, auditing login attempts, and rotating secrets.

Plan
1. Draft migration playbook (risk review, fallback) and circulate for sign-off.
2. Implement seeding script leveraging TICKET-21 CLI helpers; wire into docker-compose `init` service.
3. Extend env templates and configs across repos; verify `make dev` spins up Redis + backend with strict auth.
4. Add feature-flag toggles in backend config, iOS build settings, web env; default to strict for non-dev.
5. Update CI workflows to run smoke script; ensure secrets stored in GitHub Actions with dummy values.
6. Document onboarding + support runbooks; link from README/roadmap.

Verification
- Run `./scripts/smoke_auth.sh` against local docker-compose (passes login, refresh, logout assertions).
- `docker compose up` provisions services and seeded users; sample credentials documented.
- CI pipelines succeed with new auth tests enabled; feature flag toggles validated in staging.

File references / Changes
- `docs/auth-migration.md`, `docs/onboarding.md` updates
- `zariz/backend/scripts/seed_auth.py` (new) and Makefile hooks
- `zariz/backend/app/core/config.py` (`AUTH_MODE` flag)
- `zariz/backend/.env.example`, `zariz/backend/docker-compose.override.yml` (if any)
- `zariz/ios/Zariz/Config/AppConfig.swift` / `.xcconfig` for auth toggles
- `zariz/web-admin/.env.local.example`, `next.config.js`
- GitHub Actions workflows (`.github/workflows/*.yml`)
- `scripts/smoke_auth.sh` (new)

Notes
- Coordinate flag removal after all clients verified; update roadmap milestones accordingly.
- Ensure seeded demo passwords comply with complexity policy and are rotated after demos.
