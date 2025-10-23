import logging
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.orm import Session
from ...core.security import create_access_token, generate_refresh_token, hash_password, verify_password
from ...core.limits import limiter
from ..deps import get_db
from ..schemas import AuthLogin, TokenResponse, AuthLoginRequest, AuthTokenPair, RefreshTokenRequest
from ...db.models.user import User
from ...db.models.user_session import UserSession
from ...db.models.store_user_membership import StoreUserMembership

router = APIRouter(prefix="/auth", tags=["auth"])
_log = logging.getLogger("app")

try:
    from prometheus_client import Counter

    LOGIN_SUCCESS = Counter("auth_login_success_total", "Total successful logins")
    LOGIN_FAILURE = Counter("auth_login_failure_total", "Total failed logins")
except Exception:
    class _Noop:
        def inc(self):
            pass

    LOGIN_SUCCESS = _Noop()
    LOGIN_FAILURE = _Noop()


@router.post("/login", response_model=TokenResponse)
def login_legacy(payload: AuthLogin):
    token = create_access_token(sub=str(payload.subject), role=payload.role)
    return TokenResponse(access_token=token)


@limiter.limit("5/minute")
@router.post("/login_password", response_model=AuthTokenPair)
def login_password(
    payload: AuthLoginRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    identifier = (payload.identifier or "").strip().lower()
    pwd = payload.password or ""
    user = None
    if "@" in identifier:
        user = db.execute(select(User).where(User.email == identifier)).scalars().first()
    if user is None:
        # Try phone as-is
        user = db.execute(select(User).where(User.phone == payload.identifier.strip())).scalars().first()
    ip = request.client.host if request and request.client else "?"
    if user is None or user.status != "active" or not verify_password(pwd, user.password_hash or "!"):
        _log.info(
            "{\"event\":\"auth.login\",\"result\":\"failure\",\"ip_hash\":\"%s\"}" % (hash(ip) % 100000),
        )
        LOGIN_FAILURE.inc()
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Resolve store_ids via memberships
    stores = db.execute(select(StoreUserMembership.store_id).where(StoreUserMembership.user_id == user.id)).scalars().all()
    store_ids = list(stores)
    if not store_ids and user.default_store_id:
        store_ids = [int(user.default_store_id)]

    # Issue refresh session
    refresh_raw = generate_refresh_token()
    expires_at = datetime.now(timezone.utc) + timedelta(days=14)
    session = UserSession(user_id=user.id, refresh_token_hash=hash_password(refresh_raw), expires_at=expires_at)
    db.add(session)
    # Update last_login_at
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()
    # Create access token
    access = create_access_token(sub=str(user.id), role=user.role, store_ids=store_ids, session_id=str(session.id))
    LOGIN_SUCCESS.inc()
    return AuthTokenPair(access_token=access, refresh_token=refresh_raw)


@router.post("/refresh", response_model=AuthTokenPair)
def refresh_token(payload: RefreshTokenRequest, db: Session = Depends(get_db)):
    raw = payload.refresh_token or ""
    # Find session by hash
    # Caution: without argon2 we cannot verify against all rows efficiently; fetch all non-revoked sessions for simplicity (MVP scale)
    sessions = db.execute(select(UserSession).where(UserSession.revoked_at == None)).scalars().all()  # noqa: E711
    matched = None
    for s in sessions:
        if verify_password(raw, s.refresh_token_hash):
            matched = s
            break
    now_aware = datetime.now(timezone.utc)
    if matched is None:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    exp = matched.expires_at
    # handle naive datetimes from SQLite
    if exp.tzinfo is None:
        from datetime import datetime as _dt

        if exp < _dt.utcnow():
            raise HTTPException(status_code=401, detail="Invalid refresh token")
    else:
        if exp < now_aware:
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user = db.get(User, matched.user_id)
    if user is None or user.status != "active":
        raise HTTPException(status_code=401, detail="User inactive")
    # Compute store_ids
    stores = db.execute(select(StoreUserMembership.store_id).where(StoreUserMembership.user_id == user.id)).scalars().all()
    store_ids = list(stores)
    if not store_ids and user.default_store_id:
        store_ids = [int(user.default_store_id)]
    # Revoke old and issue new
    matched.revoked_at = now_aware
    refresh_raw = generate_refresh_token()
    expires_at = datetime.now(timezone.utc) + timedelta(days=14)
    new_session = UserSession(user_id=user.id, refresh_token_hash=hash_password(refresh_raw), expires_at=expires_at)
    db.add(new_session)
    db.commit()
    access = create_access_token(sub=str(user.id), role=user.role, store_ids=store_ids, session_id=str(new_session.id))
    return AuthTokenPair(access_token=access, refresh_token=refresh_raw)


@router.post("/logout")
def logout(payload: RefreshTokenRequest, db: Session = Depends(get_db)):
    raw = payload.refresh_token or ""
    sessions = db.execute(select(UserSession).where(UserSession.revoked_at == None)).scalars().all()  # noqa: E711
    for s in sessions:
        if verify_password(raw, s.refresh_token_hash):
            s.revoked_at = datetime.now(timezone.utc)
            db.commit()
            return {"ok": True}
    return {"ok": True}
