from __future__ import annotations

import json
from typing import Callable, Generator

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..core.config import settings
from ..db.session import get_sessionmaker
from ..db.models.user import User
from ..db.models.order import Order
from ..db.models.store import Store


bearer = HTTPBearer(auto_error=False)


def get_db() -> Generator[Session, None, None]:
    SessionLocal = get_sessionmaker()
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_identity(creds=Depends(bearer)) -> dict:
    if creds is None:
        raise HTTPException(status_code=401, detail="Missing token")
    try:
        payload = jwt.decode(creds.credentials, settings.jwt_secret, algorithms=[settings.jwt_algo])
        role = payload.get("role")
        sub = payload.get("sub")
        if not role or not sub:
            raise HTTPException(status_code=401, detail="Invalid token claims")
        return {"sub": sub, "role": role}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")


def require_role(*allowed: str) -> Callable:
    def checker(identity: dict = Depends(get_current_identity)) -> dict:
        if identity["role"] not in allowed:
            raise HTTPException(status_code=403, detail="Forbidden")
        return identity
    return checker


def maybe_current_identity(creds=Depends(bearer)) -> dict | None:
    if creds is None:
        return None
    try:
        payload = jwt.decode(creds.credentials, settings.jwt_secret, algorithms=[settings.jwt_algo])
        role = payload.get("role")
        sub = payload.get("sub")
        if not role or not sub:
            return None
        return {"sub": sub, "role": role}
    except JWTError:
        return None


# Simple idempotency model and helpers (stored per key)
from ..db.models.idempotency import IdempotencyKey


def find_idempotency(db: Session, key: str) -> IdempotencyKey | None:
    return db.get(IdempotencyKey, key)


def save_idempotency(db: Session, key: str, method: str, path: str, status_code: int, body: dict) -> None:
    rec = IdempotencyKey(key=key, method=method, path=path, status_code=status_code, response_body=json.dumps(body))
    db.merge(rec)
    db.commit()
