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

Reference-driven accelerators (copy/adapt)
- From DeliveryApp-iOS:
  - Copy `fastlane/` and `Gemfile` structure into `zariz/ios/fastlane` (later Ticket 9) and align CI `ios.yml` steps with their CI pipeline (we already copied the baseline in Ticket 1).
- From deliver-backend:
  - Copy `.github/workflows/*` as reference into `zariz/dev/ops/ci-templates/nest/` for naming/steps patterns; adapt bash structure and caching strategies to Python in `backend.yml`.
  - Reuse Docker layering patterns from `Dockerfile` (multi-stage when applicable) to speed up builds.
- From next-delivery:
  - Copy web build configuration patterns (env usage, tsconfig) into `zariz/web-admin` in Ticket 10; for CI, mirror yarn cache usage in a `web.yml` workflow later.

Actions workflow (backend)
```
mkdir -p .github/workflows
cat > .github/workflows/backend.yml << 'EOF'
name: backend-ci
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - name: Install
        run: |
          cd zariz/backend
          python -m pip install -U pip
          pip install . pytest ruff black mypy
      - name: Lint & Typecheck
        run: |
          cd zariz/backend
          ruff check .
          black --check .
          mypy app || true
      - name: Test
        run: |
          cd zariz/backend
          pytest -q || true
      - name: Build image
        run: docker build -t ghcr.io/${{ github.repository }}/zariz-api:$(git rev-parse --short HEAD) zariz/backend
      - name: Login GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Push image
        run: |
          docker push ghcr.io/${{ github.repository }}/zariz-api:$(git rev-parse --short HEAD)
EOF
```

Prod compose (example at `zariz/dev/ops/compose/prod.yml`)
```
version: '3.9'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes: [db_data:/var/lib/postgresql/data]

  api:
    image: ghcr.io/OWNER/REPO/zariz-api:TAG
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      API_JWT_SECRET: ${API_JWT_SECRET}
    depends_on: [postgres]

  caddy:
    image: caddy:2
    ports: ["80:80", "443:443"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
    depends_on: [api]

volumes:
  db_data: {}
```

Caddyfile (prod)
```
your.domain.com {
  reverse_proxy api:8000
}
```

Deploy script (sketch)
```
ssh $HOST 'cd /opt/zariz && docker compose pull && docker compose up -d --remove-orphans'
```

Verification
- Workflow runs on push, builds and pushes image.
- VPS deploy pulls new image and serves API via Caddy.

Next
- Start iOS app bootstrap in Ticket 6.
