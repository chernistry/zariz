from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ...deps import get_db, require_role
from ....core.security import hash_password
from ....db.models.store import Store
from ....db.models.user import User
from ....db.models.store_user_membership import StoreUserMembership
from ...schemas import StoreCreate, StoreUpdate, CredentialsChange, StatusChange


router = APIRouter()


@router.get("")
def list_stores(db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    stores = db.execute(select(Store)).scalars().all()
    out = []
    for s in stores:
        out.append(
            {
                "id": s.id,
                "name": s.name,
                "status": getattr(s, "status", None),
                "pickup_address": getattr(s, "pickup_address", None),
                "box_limit": getattr(s, "box_limit", None),
                "hours_text": getattr(s, "hours_text", None),
            }
        )
    return out


@router.post("")
def create_store(payload: StoreCreate, db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    s = Store(name=payload.name)
    # Optional fields if present on model
    if hasattr(s, "status") and payload.status is not None:
        setattr(s, "status", payload.status)
    if hasattr(s, "pickup_address"):
        setattr(s, "pickup_address", payload.pickup_address)
    if hasattr(s, "box_limit") and payload.box_limit is not None:
        setattr(s, "box_limit", payload.box_limit)
    if hasattr(s, "hours_text"):
        setattr(s, "hours_text", payload.hours_text)
    db.add(s)
    db.commit()
    db.refresh(s)
    return {"id": s.id, "name": s.name}


@router.get("/{store_id}")
def get_store(store_id: int, db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    s = db.get(Store, store_id)
    if s is None:
        raise HTTPException(status_code=404, detail="Store not found")
    return {"id": s.id, "name": s.name}


@router.patch("/{store_id}")
def update_store(store_id: int, payload: StoreUpdate, db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    s = db.get(Store, store_id)
    if s is None:
        raise HTTPException(status_code=404, detail="Store not found")
    if payload.name is not None:
        s.name = payload.name
    # Optional fields
    if hasattr(s, "status") and payload.status is not None:
        setattr(s, "status", payload.status)
    if hasattr(s, "pickup_address") and payload.pickup_address is not None:
        setattr(s, "pickup_address", payload.pickup_address)
    if hasattr(s, "box_limit") and payload.box_limit is not None:
        setattr(s, "box_limit", payload.box_limit)
    if hasattr(s, "hours_text") and payload.hours_text is not None:
        setattr(s, "hours_text", payload.hours_text)
    db.commit()
    return {"ok": True}


@router.post("/{store_id}/credentials")
def set_store_credentials(
    store_id: int,
    payload: CredentialsChange,
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("admin")),
):
    s = db.get(Store, store_id)
    if s is None:
        raise HTTPException(status_code=404, detail="Store not found")
    # Find existing primary membership
    primary = (
        db.execute(
            select(StoreUserMembership).where(
                StoreUserMembership.store_id == store_id, StoreUserMembership.is_primary == True  # noqa: E712
            )
        )
        .scalars()
        .first()
    )
    user: User | None = None
    # If user exists, update; else create
    if primary is not None:
        user = db.get(User, primary.user_id)
    if user is None:
        # Create new store user
        user = User(name=s.name + " Admin", role="store", status="active", phone=payload.phone or "", email=payload.email)
        if not user.phone and not user.email:
            raise HTTPException(status_code=400, detail="email or phone required")
        # Uniqueness checks for email
        if user.email:
            existing = db.execute(select(User).where(User.email == user.email)).scalars().first()
            if existing:
                raise HTTPException(status_code=409, detail="email already in use")
        if user.phone:
            existing = db.execute(select(User).where(User.phone == user.phone)).scalars().first()
            if existing:
                raise HTTPException(status_code=409, detail="phone already in use")
        if payload.password:
            user.password_hash = hash_password(payload.password)
        db.add(user)
        db.flush()
        db.add(StoreUserMembership(user_id=user.id, store_id=s.id, role_in_store="owner", is_primary=True))
    else:
        # Update existing
        if payload.email is not None:
            # ensure uniqueness
            if payload.email:
                existing = db.execute(select(User).where(User.email == payload.email, User.id != user.id)).scalars().first()
                if existing:
                    raise HTTPException(status_code=409, detail="email already in use")
            user.email = payload.email
        if payload.phone is not None:
            if payload.phone:
                existing = db.execute(select(User).where(User.phone == payload.phone, User.id != user.id)).scalars().first()
                if existing:
                    raise HTTPException(status_code=409, detail="phone already in use")
            user.phone = payload.phone or ""
        if payload.password:
            user.password_hash = hash_password(payload.password)
    db.commit()
    return {"ok": True}


@router.post("/{store_id}/status")
def set_store_status(store_id: int, payload: StatusChange, db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    s = db.get(Store, store_id)
    if s is None:
        raise HTTPException(status_code=404, detail="Store not found")
    if not hasattr(s, "status"):
        raise HTTPException(status_code=400, detail="status field not supported by model")
    setattr(s, "status", payload.status)
    db.commit()
    return {"ok": True}

