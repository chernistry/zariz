from __future__ import annotations

import json
from typing import Callable, Generator

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..core.config import settings
from ..db.models.user_session import UserSession
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


def get_current_identity(creds=Depends(bearer), db: Session = Depends(get_db)) -> dict:
    if creds is None:
        raise HTTPException(status_code=401, detail="Missing token")
    try:
        payload = jwt.decode(creds.credentials, settings.jwt_secret, algorithms=[settings.jwt_algo])
        role = payload.get("role")
        sub = payload.get("sub")
        store_ids = payload.get("store_ids")
        session_id = payload.get("session_id")
        if not role or not sub:
            raise HTTPException(status_code=401, detail="Invalid token claims")
        # If session_id is present, verify session is active (not revoked, not expired)
        if session_id is not None:
            try:
                sid = int(session_id)
                s = db.get(UserSession, sid)
                from datetime import datetime, timezone

                if s is None or s.revoked_at is not None or (s.expires_at and s.expires_at < datetime.now(timezone.utc)):
                    raise HTTPException(status_code=401, detail="Session expired")
            except Exception:
                raise HTTPException(status_code=401, detail="Invalid session")
        return {"sub": sub, "role": role, "store_ids": store_ids, "session_id": session_id}
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
        store_ids = payload.get("store_ids")
        if not role or not sub:
            return None
        return {"sub": sub, "role": role, "store_ids": store_ids}
    except JWTError:
        return None


# Simple idempotency model and helpers (stored per key)
from ..db.models.idempotency import IdempotencyKey


def find_idempotency(db: Session, key: str, method: str, path: str) -> IdempotencyKey | None:
    """Return idempotency record if key matches same method+path.

    If the key exists but for a different method or path, return an HTTP 409.
    This prevents cross-endpoint reuse of the same idempotency key.
    """
    rec = db.get(IdempotencyKey, key)
    if rec is None:
        return None
    if rec.method == method and rec.path == path:
        return rec
    raise HTTPException(status_code=409, detail="Idempotency-Key reused for different request")


def save_idempotency(db: Session, key: str, method: str, path: str, status_code: int, body: dict) -> None:
    rec = IdempotencyKey(key=key, method=method, path=path, status_code=status_code, response_body=json.dumps(body))
    db.merge(rec)
    db.commit()
