from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from ..schemas import OrderCreate, OrderRead, StatusUpdate
from ..deps import get_db, require_role, find_idempotency, save_idempotency
from ...core.limits import limiter
from ...db.models.order import Order
from ...db.models.order_event import OrderEvent
from ...db.models.device import Device
from ...services.events import events_bus
from ...worker.push import send_silent

router = APIRouter(prefix="/orders", tags=["orders"])


def price_for_boxes(boxes: int) -> tuple[int, int]:
    if boxes <= 8:
        return 35, 1
    if boxes <= 16:
        return 70, 2
    return 105, 3


def delivery_address_from_payload(payload: OrderCreate) -> str:
    parts: list[str] = []
    street = " ".join(filter(None, [payload.street.strip(), payload.building_no.strip()]))
    if street:
        parts.append(street)
    detail = ", ".join([
        p.strip()
        for p in [payload.floor or "", payload.apartment or ""]
        if p and p.strip()
    ])
    if detail:
        parts.append(detail)
    return ", ".join(parts)


@router.get("", response_model=list[OrderRead])
def list_orders(
    status_filter: Optional[str] = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("store", "admin", "courier")),
):
    q = select(Order)
    if status_filter:
        if status_filter not in {"new", "claimed", "picked_up", "delivered", "canceled"}:
            raise HTTPException(status_code=400, detail="Invalid status filter")
        q = q.where(Order.status == status_filter)
    # Object-level access
    role = identity.get("role")
    sub = identity.get("sub")
    if role == "store":
        try:
            store_id = int(sub)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid store id")
        q = q.where(Order.store_id == store_id)
    elif role == "courier":
        # Couriers can only see orders assigned to them or new ones
        try:
            courier_id = int(sub)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid courier id")
        from sqlalchemy import or_
        q = q.where(or_(Order.courier_id == courier_id, Order.status == "new"))
    rows = db.execute(q).scalars().all()
    result: list[OrderRead] = []
    for o in rows:
        result.append(
            OrderRead(
                id=o.id,
                store_id=o.store_id,
                courier_id=o.courier_id,
                status=o.status,
                pickup_address=o.pickup_address,
                delivery_address=o.delivery_address,
                recipient_first_name=o.recipient_first_name,
                recipient_last_name=o.recipient_last_name,
                phone=o.phone,
                street=o.street,
                building_no=o.building_no,
                floor=o.floor,
                apartment=o.apartment,
                boxes_count=o.boxes_count,
                boxes_multiplier=o.boxes_multiplier,
                price_total=o.price_total,
            )
        )
    return result


@limiter.limit("10/minute")
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
        existing = find_idempotency(db, idem, request.method, request.url.path)
        if existing and existing.status_code == 200:
            # Return cached body
            from fastapi.responses import JSONResponse
            import json as _json

            return JSONResponse(status_code=existing.status_code, content=_json.loads(existing.response_body))

    store_id = payload.store_id
    role = identity.get("role")
    if role == "store":
        store_id = _parse_int(identity.get("sub"))
    if store_id is None:
        raise HTTPException(status_code=400, detail="Store id required")

    pickup_address = (payload.pickup_address or "").strip()
    delivery_address = (payload.delivery_address or delivery_address_from_payload(payload)).strip()
    price, multiplier = price_for_boxes(payload.boxes_count)

    o = Order(
        store_id=store_id,
        courier_id=None,
        status="new",
        pickup_address=pickup_address,
        delivery_address=delivery_address,
        recipient_first_name=payload.recipient_first_name,
        recipient_last_name=payload.recipient_last_name,
        phone=payload.phone,
        street=payload.street,
        building_no=payload.building_no,
        floor=payload.floor or "",
        apartment=payload.apartment or "",
        boxes_count=payload.boxes_count,
        boxes_multiplier=multiplier,
        price_total=price,
    )
    db.add(o)
    db.flush()
    ev = OrderEvent(order_id=o.id, type="created")
    db.add(ev)
    db.commit()
    # Emit event (SSE) and silent push
    events_bus.publish({"type": "order.created", "order_id": o.id, "store_id": o.store_id})
    # Push to all devices (MVP); refine targeting later
    try:
        tokens = [t for (t,) in db.query(Device.token).all()]
        for t in tokens:
            send_silent(t, {"type": "order.created", "order_id": o.id})
    except Exception:
        # Don't fail API on push errors
        pass
    result = OrderRead(
        id=o.id,
        store_id=o.store_id,
        courier_id=o.courier_id,
        status=o.status,
        pickup_address=o.pickup_address,
        delivery_address=o.delivery_address,
        recipient_first_name=o.recipient_first_name,
        recipient_last_name=o.recipient_last_name,
        phone=o.phone,
        street=o.street,
        building_no=o.building_no,
        floor=o.floor,
        apartment=o.apartment,
        boxes_count=o.boxes_count,
        boxes_multiplier=o.boxes_multiplier,
        price_total=o.price_total,
    )
    if idem:
        save_idempotency(db, idem, request.method, request.url.path, 200, result.model_dump())
    return result


def _parse_int(s: str) -> Optional[int]:
    try:
        return int(s)
    except Exception:
        return None


@limiter.limit("20/minute")
@router.post("/{order_id}/claim")
def claim_order(
    order_id: int,
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("courier")),
    request: Request = None,
):
    idem = request.headers.get("Idempotency-Key") if request else None
    if idem:
        existing = find_idempotency(db, idem, request.method, request.url.path)
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
    events_bus.publish({"type": "order.claimed", "order_id": order_id, "courier_id": courier_id})
    try:
        tokens = [t for (t,) in db.query(Device.token).all()]
        for t in tokens:
            send_silent(t, {"type": "order.claimed", "order_id": order_id})
    except Exception:
        pass
    out = {"ok": True}
    if idem:
        save_idempotency(db, idem, request.method, request.url.path, 200, out)
    return out


@limiter.limit("30/minute")
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
        existing = find_idempotency(db, idem, request.method, request.url.path)
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
    events_bus.publish({"type": "order.status_changed", "order_id": o.id, "status": o.status})
    try:
        tokens = [t for (t,) in db.query(Device.token).all()]
        for t in tokens:
            send_silent(t, {"type": "order.status_changed", "order_id": o.id, "status": o.status})
    except Exception:
        pass

    out = {"ok": True, "status": o.status}
    if idem:
        save_idempotency(db, idem, request.method, request.url.path, 200, out)
    return out
