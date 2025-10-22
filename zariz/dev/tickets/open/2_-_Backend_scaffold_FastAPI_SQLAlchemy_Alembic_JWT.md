Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: Backend scaffold (FastAPI, SQLAlchemy, Alembic, JWT)

Objective
- Scaffold a FastAPI service with typed models, JWT auth, Alembic migrations, and Postgres.
- Prepare Dockerfile and compose override to run API locally with DB.

Deliverables
- FastAPI app structure under `zariz/backend`.
- SQLAlchemy models: users, stores, orders, order_events, devices.
- Alembic initialized with base migration.
- JWT auth with role support (courier, store, admin).
- Dockerfile, dev settings, `uvicorn` entry.

Reference-driven accelerators (what to copy and why)
- From deliver-backend (NestJS + Prisma):
  - Copy structural ideas: `src/modules/*`, `src/common/*`, `src/config/*` as a modular blueprint. Implement the same module boundaries in FastAPI packages:
    - `app/api/routes/*` ↔ modules; `app/core/*` ↔ config; `app/common/*` for cross-cutting.
  - Map Prisma schema (users/stores/orders/events) into SQLAlchemy models. Copy `zariz/references/deliver-backend/prisma/schema.prisma` locally as reference (`zariz/backend/docs/prisma_schema_reference.prisma`) to keep the field list visible when implementing Alembic migrations.
  - Borrow validation patterns (DTOs) and RBAC guard approach to inform FastAPI dependencies (Ticket 3), not code.
  - Copy `API_TESTING_GUIDE.md` to `zariz/backend/README.testing.md` as a template for API examples; rewrite endpoints to our FastAPI paths.
- From food-delivery-ios-app (Backend/Express):
  - Use as a reference for push notification event flow only (order.created → notify); do not copy Express runtime.
- From DeliveryApp-iOS (Analytics/Quality):
  - Mirror code organization discipline; keep typed boundaries and unit-testable functions.

File structure
```
zariz/backend/
  app/
    api/
      __init__.py
      deps.py
      routes/
        __init__.py
        auth.py
        orders.py
        devices.py
    core/
      config.py
      security.py
    db/
      base.py
      session.py
      models/
        __init__.py
        user.py
        store.py
        order.py
        device.py
        order_event.py
    main.py
  alembic/
  alembic.ini
  pyproject.toml
  Dockerfile
  README.md
```

Step-by-step
1) pyproject & deps
```
cat > zariz/backend/pyproject.toml << 'EOF'
[project]
name = "zariz-api"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
  "fastapi~=0.115",
  "uvicorn[standard]~=0.30",
  "pydantic~=2.9",
  "SQLAlchemy~=2.0",
  "psycopg2-binary~=2.9",
  "alembic~=1.13",
  "python-jose[cryptography]~=3.3",
  "passlib[bcrypt]~=1.7",
  "tenacity~=9.0",
]

[tool.black]
line-length = 100
target-version = ["py312"]
EOF
```

2) Config and DB session
```
mkdir -p zariz/backend/app/{api/routes,core,db/models}
cat > zariz/backend/app/core/config.py << 'EOF'
from pydantic import BaseModel
import os


class Settings(BaseModel):
    db_url: str = (
        f"postgresql://{os.getenv('POSTGRES_USER','zariz')}:{os.getenv('POSTGRES_PASSWORD','zariz')}@"
        f"{os.getenv('POSTGRES_HOST','localhost')}:{os.getenv('POSTGRES_PORT','5432')}/"
        f"{os.getenv('POSTGRES_DB','zariz')}"
    )
    jwt_secret: str = os.getenv("API_JWT_SECRET", "dev_secret_change_me")
    jwt_algo: str = "HS256"


settings = Settings()
EOF

cat > zariz/backend/app/db/session.py << 'EOF'
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from .base import Base
from ..core.config import settings

engine = create_engine(settings.db_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def init_db():
    Base.metadata.create_all(bind=engine)
EOF

cat > zariz/backend/app/db/base.py << 'EOF'
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass
EOF
```

3) Models
```
cat > zariz/backend/app/db/models/user.py << 'EOF'
from sqlalchemy import String, Enum, Integer
from sqlalchemy.orm import Mapped, mapped_column
from ..base import Base


class Role(str, Enum):
    courier = "courier"
    store = "store"
    admin = "admin"


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    phone: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(String(16), index=True)
    store_id: Mapped[int | None]
EOF

cat > zariz/backend/app/db/models/store.py << 'EOF'
from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from ..base import Base


class Store(Base):
    __tablename__ = "stores"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(120), unique=True)
EOF

cat > zariz/backend/app/db/models/order.py << 'EOF'
from sqlalchemy import Integer, String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from ..base import Base


class Order(Base):
    __tablename__ = "orders"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    store_id: Mapped[int] = mapped_column(ForeignKey("stores.id"))
    courier_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    status: Mapped[str] = mapped_column(String(32), index=True)  # new/claimed/picked_up/delivered/canceled
    pickup_address: Mapped[str] = mapped_column(String(255))
    delivery_address: Mapped[str] = mapped_column(String(255))
EOF

cat > zariz/backend/app/db/models/device.py << 'EOF'
from sqlalchemy import Integer, String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from ..base import Base


class Device(Base):
    __tablename__ = "devices"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    platform: Mapped[str] = mapped_column(String(16))  # ios
    token: Mapped[str] = mapped_column(String(256), unique=True)
EOF

cat > zariz/backend/app/db/models/order_event.py << 'EOF'
from sqlalchemy import Integer, String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from ..base import Base


class OrderEvent(Base):
    __tablename__ = "order_events"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"))
    type: Mapped[str] = mapped_column(String(32))  # created/claimed/picked_up/delivered/canceled
EOF
```

4) Security helpers (JWT)
```
cat > zariz/backend/app/core/security.py << 'EOF'
from datetime import datetime, timedelta, timezone
from jose import jwt
from typing import Any
from .config import settings


def create_access_token(sub: str, role: str, expires_in: int = 3600) -> str:
    now = datetime.now(timezone.utc)
    to_encode: dict[str, Any] = {"sub": sub, "role": role, "iat": int(now.timestamp())}
    to_encode["exp"] = int((now + timedelta(seconds=expires_in)).timestamp())
    return jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algo)
EOF
```

5) API skeleton
```
cat > zariz/backend/app/api/routes/auth.py << 'EOF'
from fastapi import APIRouter

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login")
def login():
    return {"access_token": "TODO", "token_type": "bearer"}
EOF

cat > zariz/backend/app/api/routes/orders.py << 'EOF'
from fastapi import APIRouter

router = APIRouter(prefix="/orders", tags=["orders"])


@router.get("")
def list_orders():
    return []
EOF

cat > zariz/backend/app/api/routes/devices.py << 'EOF'
from fastapi import APIRouter

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register")
def register_device():
    return {"ok": True}
EOF

cat > zariz/backend/app/api/__init__.py << 'EOF'
from fastapi import APIRouter
from .routes import auth, orders, devices

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(orders.router)
api_router.include_router(devices.router)
EOF

cat > zariz/backend/app/main.py << 'EOF'
from fastapi import FastAPI
from .api import api_router

app = FastAPI(title="Zariz API")
app.include_router(api_router, prefix="/v1")
EOF
```

6) Alembic init (commands)
```
cd zariz/backend
python -m venv venv && . venv/bin/activate
pip install -U pip && pip install -e .
alembic init alembic
# Edit alembic.ini sqlalchemy.url to use env var or leave blank; in env.py, import settings.db_url
```

7) Dockerfile
```
cat > zariz/backend/Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY pyproject.toml /app/
RUN pip install --no-cache-dir -U pip && pip install --no-cache-dir .
COPY app /app/app
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
```

8) Compose override (attach API)
```
cat >> docker-compose.yml << 'EOF'
  api:
    build: ./zariz/backend
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_HOST: ${POSTGRES_HOST}
      POSTGRES_PORT: ${POSTGRES_PORT}
      API_JWT_SECRET: ${API_JWT_SECRET}
    depends_on:
      - postgres
    ports:
      - "8000:8000"
EOF
```

Verification
- `docker compose build api && docker compose up -d api postgres` then GET http://localhost:8000/v1/orders ⇒ []
- Alembic initialized; base migration pending.

Copy/Integrate
```
# Keep a local reference to Prisma schema for field parity (no runtime use):
mkdir -p zariz/backend/docs
cp -f zariz/references/deliver-backend/prisma/schema.prisma zariz/backend/docs/prisma_schema_reference.prisma || true

# Testing guide template to adjust for our endpoints
cp -f zariz/references/deliver-backend/API_TESTING_GUIDE.md zariz/backend/README.testing.md || true
```

Next
- Implement core endpoints and atomic claim in Ticket 3.
