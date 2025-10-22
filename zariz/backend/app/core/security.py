from datetime import datetime, timedelta, timezone
from typing import Any

from jose import jwt

from .config import settings


def create_access_token(sub: str, role: str, expires_in: int = 3600) -> str:
    now = datetime.now(timezone.utc)
    to_encode: dict[str, Any] = {"sub": sub, "role": role, "iat": int(now.timestamp())}
    to_encode["exp"] = int((now + timedelta(seconds=expires_in)).timestamp())
    return jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algo)

