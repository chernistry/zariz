from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from ..schemas import OrderCreate, OrderRead, StatusUpdate
from ..deps import get_db, require_role, find_idempotency, save_idempotency
from ...db.models.order import Order
from ...db.models.order_event import OrderEvent

router = APIRouter(prefix="/orders", tags=["orders"])


@router.get("", response_model=list[OrderRead])
def list_orders(
    status_filter: Optional[str] = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
):
    q = select(Order)
    if status_filter:
        if status_filter not in {"new", "claimed", "picked_up", "delivered", "canceled"}:
            raise HTTPException(status_code=400, detail="Invalid status filter")
        q = q.where(Order.status == status_filter)
    rows = db.execute(q).scalars().all()
    return [
        OrderRead(
            id=o.id,
            store_id=o.store_id,
            courier_id=o.courier_id,
            status=o.status,
            pickup_address=o.pickup_address,
            delivery_address=o.delivery_address,
        )
        for o in rows
    ]


@router.post("", response_model=OrderRead)
def create_order(
    payload: OrderCreate,
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("store", "admin")),
    request: Request = None,
):
    # Simple idempotency handling (if key present)
    idem = request.headers.get("Idempotency-Key") if request else None
    if idem:
        existing = find_idempotency(db, idem)
        if existing and existing.status_code == 200:
            # Return cached body
            from fastapi.responses import JSONResponse
            import json as _json

            return JSONResponse(status_code=existing.status_code, content=_json.loads(existing.response_body))

    o = Order(
        store_id=payload.store_id,
        courier_id=None,
        status="new",
        pickup_address=payload.pickup_address,
        delivery_address=payload.delivery_address,
    )
    db.add(o)
    db.flush()
    ev = OrderEvent(order_id=o.id, type="created")
    db.add(ev)
    db.commit()
    result = OrderRead(
        id=o.id,
        store_id=o.store_id,
        courier_id=o.courier_id,
        status=o.status,
        pickup_address=o.pickup_address,
        delivery_address=o.delivery_address,
    )
    if idem:
        save_idempotency(db, idem, request.method, request.url.path, 200, result.model_dump())
    return result


def _parse_int(s: str) -> Optional[int]:
    try:
        return int(s)
    except Exception:
        return None


@router.post("/{order_id}/claim")
def claim_order(
    order_id: int,
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("courier")),
    request: Request = None,
):
    idem = request.headers.get("Idempotency-Key") if request else None
    if idem:
        existing = find_idempotency(db, idem)
        if existing and existing.status_code == 200:
            from fastapi.responses import JSONResponse
            import json as _json

            return JSONResponse(status_code=existing.status_code, content=_json.loads(existing.response_body))

    courier_id = _parse_int(identity["sub"])
    if courier_id is None:
        raise HTTPException(status_code=400, detail="Invalid courier id")
    res = db.execute(
        text("UPDATE orders SET status='claimed', courier_id=:cid WHERE id=:id AND status='new'"),
        {"cid": courier_id, "id": order_id},
    )
    if res.rowcount == 0:
        db.rollback()
        raise HTTPException(status_code=409, detail="Order already claimed or not found")
    db.add(OrderEvent(order_id=order_id, type="claimed"))
    db.commit()
    out = {"ok": True}
    if idem:
        save_idempotency(db, idem, request.method, request.url.path, 200, out)
    return out


@router.post("/{order_id}/status")
def update_status(
    order_id: int,
    payload: StatusUpdate,
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("courier")),
    request: Request = None,
):
    idem = request.headers.get("Idempotency-Key") if request else None
    if idem:
        existing = find_idempotency(db, idem)
        if existing and existing.status_code == 200:
            from fastapi.responses import JSONResponse
            import json as _json

            return JSONResponse(status_code=existing.status_code, content=_json.loads(existing.response_body))

    courier_id = _parse_int(identity["sub"])
    if courier_id is None:
        raise HTTPException(status_code=400, detail="Invalid courier id")

    # Enforce monotonic state machine
    o = db.get(Order, order_id)
    if not o:
        raise HTTPException(status_code=404, detail="Order not found")
    if o.courier_id not in (None, courier_id):
        raise HTTPException(status_code=403, detail="Not allowed to update this order")

    allowed = {
        "claimed": {"picked_up", "canceled"},
        "picked_up": {"delivered", "canceled"},
    }
    if o.status == "new":
        raise HTTPException(status_code=400, detail="Claim first")
    next_status = payload.status
    if next_status not in allowed.get(o.status, set()):
        raise HTTPException(status_code=400, detail="Illegal transition")

    o.status = next_status
    if o.courier_id is None:
        o.courier_id = courier_id
    db.add(OrderEvent(order_id=o.id, type=next_status))
    db.commit()

    out = {"ok": True, "status": o.status}
    if idem:
        save_idempotency(db, idem, request.method, request.url.path, 200, out)
    return out
