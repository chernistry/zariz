from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ...deps import get_db, require_role
from ....core.security import hash_password
from ....db.models.user import User
from ...schemas import CourierCreate, CourierUpdate, CredentialsChange, StatusChange


router = APIRouter()


@router.get("")
def list_couriers(db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    cs = db.execute(select(User).where(User.role == "courier")).scalars().all()
    return [
        {
            "id": c.id,
            "name": c.name,
            "email": c.email,
            "phone": c.phone,
            "capacity_boxes": c.capacity_boxes,
            "status": c.status,
        }
        for c in cs
    ]


@router.post("")
def create_courier(payload: CourierCreate, db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    if not payload.email and not payload.phone:
        raise HTTPException(status_code=400, detail="email or phone required")
    # Uniqueness checks
    if payload.email:
        existing = db.execute(select(User).where(User.email == payload.email)).scalars().first()
        if existing:
            raise HTTPException(status_code=409, detail="email already in use")
    if payload.phone:
        existing = db.execute(select(User).where(User.phone == payload.phone)).scalars().first()
        if existing:
            raise HTTPException(status_code=409, detail="phone already in use")
    u = User(
        name=payload.name,
        role="courier",
        status=payload.status or "active",
        phone=payload.phone or "",
        email=payload.email,
        capacity_boxes=payload.capacity_boxes or 8,
        password_hash=hash_password(payload.password) if hasattr(payload, "password") and getattr(payload, "password") else "!",
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    return {"id": u.id, "name": u.name}


@router.get("/{user_id}")
def get_courier(user_id: int, db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    u = db.get(User, user_id)
    if u is None or u.role != "courier":
        raise HTTPException(status_code=404, detail="Courier not found")
    return {"id": u.id, "name": u.name}


@router.patch("/{user_id}")
def update_courier(user_id: int, payload: CourierUpdate, db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    u = db.get(User, user_id)
    if u is None or u.role != "courier":
        raise HTTPException(status_code=404, detail="Courier not found")
    if payload.name is not None:
        u.name = payload.name
    if payload.capacity_boxes is not None:
        u.capacity_boxes = payload.capacity_boxes
    if payload.status is not None:
        u.status = payload.status
    if payload.email is not None:
        if payload.email:
            existing = db.execute(select(User).where(User.email == payload.email, User.id != u.id)).scalars().first()
            if existing:
                raise HTTPException(status_code=409, detail="email already in use")
        u.email = payload.email
    if payload.phone is not None:
        if payload.phone:
            existing = db.execute(select(User).where(User.phone == payload.phone, User.id != u.id)).scalars().first()
            if existing:
                raise HTTPException(status_code=409, detail="phone already in use")
        u.phone = payload.phone or ""
    db.commit()
    return {"ok": True}


@router.post("/{user_id}/credentials")
def set_courier_credentials(user_id: int, payload: CredentialsChange, db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    u = db.get(User, user_id)
    if u is None or u.role != "courier":
        raise HTTPException(status_code=404, detail="Courier not found")
    if payload.email is not None:
        if payload.email:
            existing = db.execute(select(User).where(User.email == payload.email, User.id != u.id)).scalars().first()
            if existing:
                raise HTTPException(status_code=409, detail="email already in use")
        u.email = payload.email
    if payload.phone is not None:
        if payload.phone:
            existing = db.execute(select(User).where(User.phone == payload.phone, User.id != u.id)).scalars().first()
            if existing:
                raise HTTPException(status_code=409, detail="phone already in use")
        u.phone = payload.phone or ""
    if payload.password:
        u.password_hash = hash_password(payload.password)
    db.commit()
    return {"ok": True}


@router.post("/{user_id}/status")
def set_courier_status(user_id: int, payload: StatusChange, db: Session = Depends(get_db), identity: dict = Depends(require_role("admin"))):
    u = db.get(User, user_id)
    if u is None or u.role != "courier":
        raise HTTPException(status_code=404, detail="Courier not found")
    u.status = payload.status
    db.commit()
    return {"ok": True}

