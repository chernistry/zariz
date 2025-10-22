Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: CI/CD and single-VPS deployment

Objective
- Add GitHub Actions pipelines for backend (lint/test/build/publish) and later iOS/web.
- Prepare single-VPS deploy with Docker Compose + Caddy reverse proxy.

Deliverables
- `.github/workflows/backend.yml` running ruff/black/mypy/pytest, building/pushing Docker image to GHCR.
- Production compose file and Caddy config for API + web.
- Simple deploy script (ssh) to pull and restart services.

Implementation Summary
- Workflow added at `.github/workflows/backend.yml`:
  - Python 3.12 setup, install deps; run ruff/black/mypy/pytest; build and push GHCR image `ghcr.io/<owner>/<repo>/zariz-api` with tags `<sha7>` and `latest` on default branch.
  - Uses `docker/build-push-action`; sets `packages: write` permission.
- Dockerfile fixed (`zariz/backend/Dockerfile`) to copy app before `pip install .`.
- Prod Compose at `zariz/dev/ops/compose/prod.yml` with services `postgres`, `api`, `caddy`; CORS env passed through to API.
- Caddyfile at `zariz/dev/ops/compose/Caddyfile` with `reverse_proxy api:8000` for `your.domain.com`.
- Deploy script at `zariz/dev/ops/deploy/deploy.sh` that SSHes into the VPS, updates the image tag in compose, pulls, and restarts services.
- Dev compose updated (`docker-compose.yml`) to pass `CORS_ALLOW_ORIGINS` to API.

How to Verify
- CI: Push; check Actions → backend-ci. Image appears under GHCR.
- VPS: Place repo at `/opt/zariz` on server, set `.env`, then from local:
  - `HOST=user@server ./zariz/dev/ops/deploy/deploy.sh latest`
  - Ensure DNS → VPS; Caddy serves API on 443.

Notes
- Lint/format/type are currently non-blocking in CI; tighten later when codebase is stabilized.
- Store secrets in server-side `.env`; do not commit secrets.

