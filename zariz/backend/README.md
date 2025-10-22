Zariz API (FastAPI)

Run locally (without Docker)
- `cd zariz/backend`
- `python3 -m venv .venv && source .venv/bin/activate`
- `pip install -e .`
- `uvicorn app.main:app --reload`

Run with Docker Compose
- Ensure Docker is running
- `docker compose build api && docker compose up -d api postgres`
- Open `http://localhost:8000/v1/orders`

Alembic Migrations
- Configure DB via env (.env): POSTGRES_* vars
- `alembic revision --autogenerate -m "init"`
- `alembic upgrade head`

