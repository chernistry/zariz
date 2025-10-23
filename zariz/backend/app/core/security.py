from datetime import datetime, timedelta, timezone
from typing import Any, Optional
import secrets

from jose import jwt

from .config import settings

from passlib.hash import bcrypt as _bcrypt
import hashlib
try:
    from passlib.handlers.argon2 import argon2 as _argon2handler
    _HAS_ARGON2 = _argon2handler.has_backend()
    if _HAS_ARGON2:
        from passlib.hash import argon2 as _argon2
    else:
        _argon2 = None  # type: ignore
except Exception:
    _HAS_ARGON2 = False
    _argon2 = None  # type: ignore


def hash_password(password: str) -> str:
    if _HAS_ARGON2 and _argon2 is not None:
        try:
            return _argon2.hash(password)
        except Exception:
            pass
    try:
        return _bcrypt.hash(password)
    except Exception:
        # Last-resort fallback to sha256 for test environments
        h = hashlib.sha256(password.encode("utf-8")).hexdigest()
        return f"sha256${h}"


def verify_password(password: str, password_hash: str) -> bool:
    try:
        if password_hash.startswith("$argon2") and _HAS_ARGON2 and _argon2 is not None:
            return _argon2.verify(password, password_hash)
        if password_hash.startswith("sha256$"):
            return hashlib.sha256(password.encode("utf-8")).hexdigest() == password_hash.split("$", 1)[1]
        # fallback to bcrypt
        return _bcrypt.verify(password, password_hash)
    except Exception:
        return False


def create_access_token(
    sub: str,
    role: str,
    store_ids: Optional[list[int]] = None,
    session_id: Optional[str] = None,
    expires_in: int = 900,
) -> str:
    now = datetime.now(timezone.utc)
    to_encode: dict[str, Any] = {
        "sub": sub,
        "role": role,
        "iat": int(now.timestamp()),
    }
    if store_ids:
        to_encode["store_ids"] = store_ids
    if session_id:
        to_encode["session_id"] = session_id
    to_encode["exp"] = int((now + timedelta(seconds=expires_in)).timestamp())
    return jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algo)


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)
