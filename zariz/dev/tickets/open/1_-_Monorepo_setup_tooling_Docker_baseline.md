Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: Monorepo setup, tooling, Docker baseline

Objective
- Establish the Zariz monorepo structure (iOS app, FastAPI backend, SvelteKit web panel).
- Add shared tooling: editorconfig, gitignore, pre-commit, base Docker Compose, .env templates.
- Prepare for fast local dev and simple single-VPS deploy.

Deliverables
- Folder structure and baseline files created.
- docker-compose.yml for local dev with Postgres and reverse proxy.
- .env.example for services + Makefile for common tasks.
- Pre-commit hooks (format, lint basics) wired for backend/web.

Reference-driven accelerators (what to copy and adapt)
- From DeliveryApp-iOS (iOS quality baseline):
  - Copy `DeliveryApp-iOS/.github/workflows/CI.yml` to `.github/workflows/ios.yml` as a starting point; adjust scheme/bundle IDs later in Ticket 9.
  - Copy `DeliveryApp-iOS/Makefile` targets you find useful (e.g., xcodebuild wrappers) into our root `Makefile` under separate "ios-*" targets, or keep in `zariz/ios/Makefile`.
  - Reuse folder naming conventions from `DeliveryApp-iOS/Dependencies` to inform our Swift Package module names (applied in Tickets 6–8).
- From deliver-backend (DevOps baseline):
  - Mirror `deliver-backend/.github/workflows` pipeline structure for build/publish naming conventions; adapt to Python in Ticket 5.
  - Borrow `.dockerignore`/Docker layering ideas from `deliver-backend/Dockerfile` to keep our images slim (apply in Ticket 2/5).
- From next-delivery (web panel baseline):
  - Use Next.js project structure as a template; we’ll copy the app skeleton in Ticket 10.

Repository Layout (create if missing)
```
zariz/
  backend/
    app/
      __init__.py
    tests/
    alembic/
  ios/
    Zariz.xcodeproj (later)
    Zariz/
  web-admin/
    src/
    tests/
  dev/
    tickets/
      coding_rules.md
      roadmap.md
    ops/
      nginx/
      compose/
  .editorconfig
  .gitignore
  docker-compose.yml
  Makefile
  .env.example
```

Step-by-step
1) Create root hygiene files
```
cat > .editorconfig << 'EOF'
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
max_line_length = 100
EOF

cat > .gitignore << 'EOF'
# General
.DS_Store
*.log
.env
venv/
__pycache__/
.pytest_cache/
.mypy_cache/
dist/
node_modules/
build/
.swiftpm/
.build/
DerivedData/
xcuserdata/
*.xcuserstate
EOF
```

2) Add .env template (copy to .env for local)
```
cat > .env.example << 'EOF'
POSTGRES_USER=zariz
POSTGRES_PASSWORD=zariz
POSTGRES_DB=zariz
POSTGRES_PORT=5432
POSTGRES_HOST=postgres

API_PORT=8000
API_HOST=api
API_JWT_SECRET=replace_me

NGINX_HTTP_PORT=8080
EOF
```

3) Docker Compose for local dev (DB + reverse proxy; app services will come in Ticket #2/#10)
```
cat > docker-compose.yml << 'EOF'
version: "3.9"
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports: ["${POSTGRES_PORT}:5432"]
    volumes:
      - db_data:/var/lib/postgresql/data

  nginx:
    image: caddy:2
    ports:
      - "${NGINX_HTTP_PORT}:80"
    volumes:
      - ./zariz/dev/ops/nginx/Caddyfile:/etc/caddy/Caddyfile:ro
    depends_on:
      - postgres
volumes:
  db_data: {}
EOF
```

4) Minimal Caddyfile (reverse proxy stub) at `zariz/dev/ops/nginx/Caddyfile`
```
{ 
  auto_https off
}
:80 {
  respond "Zariz dev reverse proxy up" 200
}
```

5) Makefile helpers
```
cat > Makefile << 'EOF'
.PHONY: up down logs
up:
	docker compose up -d
down:
	docker compose down -v
logs:
	docker compose logs -f --tail=200
EOF
```

6) Pre-commit (optional now; wire in Tickets #2/#10)
- Backend: ruff, black, mypy, pytest
- Web: eslint, prettier, typecheck

7) Copy initial CI scaffolds (will be refined later)
```
mkdir -p .github/workflows
# iOS baseline CI from DeliveryApp-iOS
cp -f zariz/references/DeliveryApp-iOS/.github/workflows/CI.yml .github/workflows/ios.yml || true
# Backend CI will be authored in Ticket 5 (FastAPI specifics)
```

Verification
- `cp .env.example .env` then `make up`; open http://localhost:8080 → should answer with Caddy response.
- Confirm `zariz/` tree exists and is tracked.

Next
- Proceed to Ticket 2 (Backend scaffold).
