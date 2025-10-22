Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: Core APIs — auth, orders CRUD, claim (atomic), idempotency

Objective
- Implement core endpoints with RBAC, atomic claim semantics, and idempotency keys.
- Generate OpenAPI 3.1 spec and enable Swagger UI.
- Add pytest tests for claim race and status transitions.

Reference-driven accelerators (copy/adapt)
- deliver-backend (NestJS + Prisma):
  - Use `prisma/schema.prisma` to ensure field parity for `users`, `stores`, `orders`, `order_events` (copy placed at `zariz/backend/docs/prisma_schema_reference.prisma`).
  - Adopt module/guard concepts: port to FastAPI via `deps.require_role` and per-route guards (not a direct code copy).
  - Reuse error semantics where suitable (409 for conflicts, 403 for RBAC).
- food-delivery-ios-app (Backend):
  - Reference event naming and push flow order for later notifications (Ticket 4). No runtime code copied.
- DeliveryApp-iOS / Swift-DeliveryApp:
  - No server code; keep OpenAPI contract consistent with iOS client models.

Endpoints (prefix `/v1`)
- `POST /auth/login` → returns `{access_token, token_type}` (JWT with role claim).
- `GET /orders?status=new|claimed|picked_up|delivered` → filter by role.
- `POST /orders` (store role) → create order.
- `POST /orders/{id}/claim` (courier) → atomic status: new→claimed, set `courier_id`.
- `POST /orders/{id}/status` (courier) body `{status}` → picked_up/delivered/canceled.
- `POST /devices/register` (any) `{platform, token}` → upsert device.

RBAC
- JWT `role` claim. FastAPI dep ensures role-based access per route.
```
# zariz/backend/app/api/deps.py
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer
from jose import jwt, JWTError
from ..core.config import settings

bearer = HTTPBearer()

def get_current_user_role(creds=Depends(bearer)) -> str:
    try:
        payload = jwt.decode(creds.credentials, settings.jwt_secret, algorithms=[settings.jwt_algo])
        return payload.get("role")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

def require_role(*allowed: str):
    def checker(role: str = Depends(get_current_user_role)):
        if role not in allowed:
            raise HTTPException(status_code=403, detail="Forbidden")
        return role
    return checker
```

Atomic claim
- Use single `UPDATE ... WHERE id=:id AND status='new'` with rowcount check.
- Return 409 when already claimed.
```
# zariz/backend/app/api/routes/orders.py (append)
from fastapi import Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session
from ...db.session import SessionLocal
from ..deps import require_role

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/{order_id}/claim")
def claim_order(order_id: int, db: Session = Depends(get_db), role: str = Depends(require_role("courier"))):
    sql = text("""
        UPDATE orders SET status='claimed' WHERE id=:id AND status='new'
    """)
    res = db.execute(sql, {"id": order_id})
    if res.rowcount == 0:
        raise HTTPException(status_code=409, detail="Order already claimed or not found")
    db.commit()
    return {"ok": True}
```

Idempotency
- Accept header `Idempotency-Key` for claim/status updates.
- Create table `idempotency_keys` with `(key, method, path, response_hash)`; on repeat, return cached response.
Alembic migration:
```
CREATE TABLE idempotency_keys (
  key TEXT PRIMARY KEY,
  method TEXT NOT NULL,
  path TEXT NOT NULL,
  response_hash TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT now()
);
```
FastAPI dependency:
```
# zariz/backend/app/api/deps.py (append sketch)
from fastapi import Request

def idempotency_guard(request: Request):
    idem = request.headers.get("Idempotency-Key")
    # Look up and short-circuit if present, else record post-response (use a custom middleware)
    return idem
```
Implementation note: For MVP, allow missing key; if present, enforce once-only semantics on write endpoints.

OpenAPI & Docs
```
# zariz/backend/app/main.py (ensure)
app = FastAPI(title="Zariz API", version="0.1.0")
# FastAPI auto-generates /docs and /openapi.json
```

Tests (pytest)
- Simulate two concurrent claims on the same order; expect one 200 and one 409.
```
def test_atomic_claim(client, seeded_order):
    ok = client.post(f"/v1/orders/{seeded_order}/claim", headers={"Authorization": "Bearer ..."})
    conflict = client.post(f"/v1/orders/{seeded_order}/claim", headers={"Authorization": "Bearer ..."})
    assert ok.status_code == 200
    assert conflict.status_code == 409
```

Verification
- Run local DB + API, create order via store role, list via courier, claim and confirm 409 on second attempt.

Copy/Integrate
```
# Keep parity doc nearby when writing Pydantic models
ls zariz/backend/docs/prisma_schema_reference.prisma || true
```

Next
- Add notifications worker/APNs device registry in Ticket 4.

---

Implementation log (executed)
- RBAC dependencies
  - Added `get_current_identity`, `require_role`, and `maybe_current_identity` in `zariz/backend/app/api/deps.py:1`.
  - Added `get_db` using a lazily constructed sessionmaker for easier testing.
- Idempotency
  - Added SQLAlchemy model `IdempotencyKey` at `zariz/backend/app/db/models/idempotency.py:1`.
  - Helpers `find_idempotency`/`save_idempotency` in `deps.py` and per-route logic for POST endpoints.
- Schemas
  - `zariz/backend/app/api/schemas.py:1` with `AuthLogin`, `TokenResponse`, `OrderCreate`, `OrderRead`, `StatusUpdate`, `DeviceRegister`.
- Routes
  - Auth: `POST /v1/auth/login` returning JWT with role `zariz/backend/app/api/routes/auth.py:1`.
  - Orders: list/create/claim/status `zariz/backend/app/api/routes/orders.py:1` with atomic claim (`single UPDATE ... WHERE status='new'`) and status transitions.
  - Devices: `POST /v1/devices/register` upsert by token; optional auth `zariz/backend/app/api/routes/devices.py:1`.
- DB and Alembic
  - Exposed models in `zariz/backend/app/db/base.py:1` for Alembic autogenerate; session creation refactored (`zariz/backend/app/db/session.py:1`).
- CORS + Docs
  - Enabled CORS allowlist via `CORS_ALLOW_ORIGINS` in `zariz/backend/app/main.py:1`; updated `.env.example:1`.
- Tests
  - Added pytest suite using SQLite: `zariz/backend/tests/conftest.py:1`, `zariz/backend/tests/test_core_apis.py:1`.
  - Verified: 4 tests green including atomic claim and idempotency reuse.

How to verify locally
- Without Docker:
  - `cd zariz/backend && python3 -m venv .venv && source .venv/bin/activate`
  - `pip install -e . && pip install httpx pytest`
  - `pytest -q` → expect 4 passed
  - `uvicorn app.main:app --reload` and use `/docs`.
- With Docker (requires Docker running):
  - `docker compose up -d postgres api`
  - `curl -s http://localhost:8000/v1/orders` → `[]`
  - Obtain a token: `POST /v1/auth/login {"subject":"1","role":"store"}`
  - Create order: `POST /v1/orders` with token and body from schemas.
