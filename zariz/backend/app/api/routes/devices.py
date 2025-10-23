from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..schemas import DeviceRegister
from ..deps import get_db, maybe_current_identity
from ...db.models.device import Device

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register")
def register_device(payload: DeviceRegister, db: Session = Depends(get_db), identity: dict | None = Depends(maybe_current_identity)):
    user_id = None
    if identity and identity.get("sub"):
        try:
            user_id = int(identity["sub"])  # optional association
        except Exception:
            user_id = None
    # Upsert by token
    existing = db.execute(select(Device).where(Device.token == payload.token)).scalar_one_or_none()
    if existing:
        if user_id:
            existing.user_id = user_id
        existing.platform = payload.platform
        db.add(existing)
        db.commit()
        return {"ok": True, "updated": True}
    d = Device(user_id=user_id, platform=payload.platform, token=payload.token)
    db.add(d)
    db.commit()
    return {"ok": True, "created": True}
