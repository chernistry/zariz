from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..deps import get_db, require_role
from ...db.models.user import User
from ...db.models.order import Order


router = APIRouter(prefix="/couriers", tags=["couriers"])


@router.get("")
def list_couriers(
    available_only: Optional[bool] = Query(default=False),
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("admin")),
):
    couriers = db.execute(select(User).where(User.role == "courier")).scalars().all()
    out: list[dict] = []
    for u in couriers:
        load = (
            db.execute(
                select(func.coalesce(func.sum(Order.boxes_count), 0)).where(
                    Order.courier_id == u.id, Order.status.in_(["claimed", "picked_up"])
                )
            ).scalar()
            or 0
        )
        cap = u.capacity_boxes or 8
        avail = max(0, cap - int(load))
        if available_only and avail <= 0:
            continue
        out.append(
            {
                "id": u.id,
                "name": getattr(u, "name", str(u.id)),
                "capacity_boxes": cap,
                "load_boxes": int(load),
                "available_boxes": avail,
            }
        )
    out.sort(key=lambda x: (-x["available_boxes"], x["id"]))
    return out

