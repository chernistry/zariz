from typing import Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select, text, func
from sqlalchemy.orm import Session

from ..schemas import OrderCreate, OrderRead, StatusUpdate
from ..deps import get_db, require_role, find_idempotency, save_idempotency
from ...core.limits import limiter
from ...db.models.order import Order
from ...db.models.order_event import OrderEvent
from ...db.models.user import User
from ...db.models.device import Device
from ...db.models.store import Store
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
    store: Optional[int] = None,
    courier: Optional[int] = None,
    from_: Optional[str] = Query(default=None, alias="from"),
    to: Optional[str] = None,
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("store", "admin", "courier")),
):
    q = select(Order)
    if status_filter:
        if status_filter not in {"new", "assigned", "claimed", "picked_up", "delivered", "canceled"}:
            raise HTTPException(status_code=400, detail="Invalid status filter")
        q = q.where(Order.status == status_filter)
    # Object-level access + explicit filters
    role = identity.get("role")
    sub = identity.get("sub")
    if role == "store":
        sids = identity.get("store_ids") or []
        if sids:
            q = q.where(Order.store_id.in_(sids))
        else:
            # legacy token: sub is store id
            try:
                store_id = int(sub)
            except Exception:
                raise HTTPException(status_code=400, detail="Invalid store id")
            q = q.where(Order.store_id == store_id)
    elif role == "courier":
        try:
            courier_id = int(sub)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid courier id")
        from sqlalchemy import or_
        q = q.where(or_(Order.courier_id == courier_id, Order.status == "new"))
    else:
        # Admin can filter by store/courier
        if store is not None:
            q = q.where(Order.store_id == store)
        if courier is not None:
            q = q.where(Order.courier_id == courier)
        # Date filtering by created_at if provided (YYYY-MM-DD)
        if from_:
            try:
                dt_from = datetime.fromisoformat(from_)
                q = q.where(Order.created_at >= dt_from)
            except ValueError:
                pass
        if to:
            try:
                dt_to = datetime.fromisoformat(to)
                q = q.where(Order.created_at <= dt_to)
            except ValueError:
                pass
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
                created_at=o.created_at.isoformat() if getattr(o, "created_at", None) else None,
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
        sids = identity.get("store_ids") or []
        # Prefer explicit payload, else single membership, else legacy sub fallback
        if store_id is None and sids:
            if len(sids) == 1:
                store_id = int(sids[0])
            else:
                # ambiguous membership, require explicit store_id
                raise HTTPException(status_code=400, detail="Store id required")
        if store_id is None:
            # Legacy token fallback: sub is store id
            store_id = _parse_int(identity.get("sub"))
        # Enforce membership if we have store_ids claim
        if sids and store_id not in sids:
            raise HTTPException(status_code=403, detail="Forbidden")

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
        tokens = (
            db.query(Device.token)
            .join(User, Device.user_id == User.id, isouter=True)
            .filter(Device.platform == "ios")
            .filter((Device.user_id == None) | (User.role == "courier"))
            .all()
        )
        for (token,) in tokens:
            send_silent(token, {"type": "order.created", "order_id": o.id})
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
        created_at=o.created_at.isoformat() if getattr(o, "created_at", None) else None,
    )
    if idem:
        save_idempotency(db, idem, request.method, request.url.path, 200, result.model_dump())
    return result


@router.get("/{order_id}", response_model=OrderRead)
def get_order(order_id: int, db: Session = Depends(get_db), identity: dict = Depends(require_role("store", "admin", "courier"))):
    o = db.get(Order, order_id)
    if not o:
        raise HTTPException(status_code=404, detail="Order not found")
    role = identity.get("role")
    sub = identity.get("sub")
    if role == "store":
        sids = identity.get("store_ids") or []
        if sids:
            if o.store_id not in sids:
                raise HTTPException(status_code=403, detail="Forbidden")
        else:
            try:
                store_id = int(sub)
            except Exception:
                raise HTTPException(status_code=400, detail="Invalid store id")
            if o.store_id != store_id:
                raise HTTPException(status_code=403, detail="Forbidden")
    if role == "courier":
        try:
            courier_id = int(sub)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid courier id")
        if o.courier_id not in (None, courier_id) and o.status != "new":
            raise HTTPException(status_code=403, detail="Forbidden")
    return OrderRead(
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
        created_at=o.created_at.isoformat() if getattr(o, "created_at", None) else None,
    )


@limiter.limit("30/minute")
@router.post("/{order_id}/assign")
def assign_order(
    order_id: int,
    payload: dict,
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("admin")),
    request: Request = None,
):
    o = db.get(Order, order_id)
    if not o:
        raise HTTPException(status_code=404, detail="Order not found")
    if o.status in {"delivered", "canceled"}:
        raise HTTPException(status_code=400, detail="Cannot assign in final state")
    courier_id = payload.get("courier_id")
    if not isinstance(courier_id, int):
        raise HTTPException(status_code=400, detail="courier_id required")
    o.courier_id = courier_id
    # Move to 'assigned' (pending courier acceptance)
    if o.status in {"new", "assigned"}:
        o.status = "assigned"
    db.add(OrderEvent(order_id=o.id, type="assigned"))
    db.commit()
    events_bus.publish({"type": "order.assigned", "order_id": o.id, "courier_id": courier_id})
    try:
        tokens = (
            db.query(Device.token)
            .filter(Device.user_id == courier_id, Device.platform == "ios")
            .all()
        )
        for (token,) in tokens:
            send_silent(token, {"type": "order.assigned", "order_id": o.id, "courier_id": courier_id})
    except Exception:
        pass
    return {"ok": True}


@limiter.limit("30/minute")
@router.post("/{order_id}/cancel")
def cancel_order(
    order_id: int,
    payload: dict,
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("admin")),
    request: Request = None,
):
    o = db.get(Order, order_id)
    if not o:
        raise HTTPException(status_code=404, detail="Order not found")
    if o.status == "canceled":
        return {"ok": True}
    if o.status == "delivered":
        raise HTTPException(status_code=400, detail="Cannot cancel delivered order")
    o.status = "canceled"
    db.add(OrderEvent(order_id=o.id, type="canceled"))
    db.commit()
    events_bus.publish({"type": "order.status_changed", "order_id": o.id, "status": "canceled"})
    try:
        tokens = [t for (t,) in db.query(Device.token).filter(Device.platform == "ios").all()]
        for t in tokens:
            send_silent(t, {"type": "order.status_changed", "order_id": o.id, "status": "canceled"})
    except Exception:
        pass
    return {"ok": True}


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
    # Capacity check on acceptance
    o_target = db.get(Order, order_id)
    if not o_target:
        raise HTTPException(status_code=404, detail="Order not found")
    load = (
        db.execute(
            select(func.coalesce(func.sum(Order.boxes_count), 0)).where(
                Order.courier_id == courier_id, Order.status.in_(["claimed", "picked_up"])
            )
        ).scalar()
        or 0
    )
    # Get capacity from users table via ORM; default to 8 if user row missing
    user = db.get(User, courier_id)
    capacity = int(getattr(user, "capacity_boxes", 8) or 8)
    if int(load) + int(o_target.boxes_count) > capacity:
        raise HTTPException(status_code=409, detail="Courier capacity exceeded")

    res = db.execute(
        text(
            """
            UPDATE orders
            SET status='claimed', courier_id=:cid
            WHERE id=:id AND (
                status='new' OR (status='assigned' AND courier_id=:cid)
            )
            """
        ),
        {"cid": courier_id, "id": order_id},
    )
    if res.rowcount == 0:
        db.rollback()
        raise HTTPException(status_code=409, detail="Order already claimed or not found")
    db.add(OrderEvent(order_id=order_id, type="claimed"))
    db.commit()
    events_bus.publish({"type": "order.claimed", "order_id": order_id, "courier_id": courier_id})
    try:
        tokens = [t for (t,) in db.query(Device.token).filter(Device.platform == "ios").all()]
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
        tokens = [t for (t,) in db.query(Device.token).filter(Device.platform == "ios").all()]
        for t in tokens:
            send_silent(t, {"type": "order.status_changed", "order_id": o.id, "status": o.status})
    except Exception:
        pass

    out = {"ok": True, "status": o.status}
    if idem:
        save_idempotency(db, idem, request.method, request.url.path, 200, out)
    return out


@router.delete("/{order_id}")
def delete_order(
    order_id: int,
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("admin")),
):
    o = db.get(Order, order_id)
    if not o:
        raise HTTPException(status_code=404, detail="Order not found")
    # Delete related order events first to satisfy FKs
    db.query(OrderEvent).filter(OrderEvent.order_id == order_id).delete()
    db.delete(o)
    db.commit()
    # Emit event for realtime UIs
    events_bus.publish({"type": "order.deleted", "order_id": order_id})
    try:
        tokens = [t for (t,) in db.query(Device.token).filter(Device.platform == "ios").all()]
        for t in tokens:
            send_silent(t, {"type": "order.deleted", "order_id": order_id})
    except Exception:
        pass
    return {"ok": True}

@limiter.limit("20/minute")
@router.post("/{order_id}/decline")
def decline_order(
    order_id: int,
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("courier")),
    request: Request = None,
):
    courier_id = _parse_int(identity["sub"])
    if courier_id is None:
        raise HTTPException(status_code=400, detail="Invalid courier id")
    o = db.get(Order, order_id)
    if not o:
        raise HTTPException(status_code=404, detail="Order not found")
    # Only decline when assigned and either unassigned courier or assigned to this courier
    if o.status != "assigned" or (o.courier_id not in (None, courier_id)):
        raise HTTPException(status_code=400, detail="Cannot decline this order")
    o.status = "new"
    o.courier_id = None
    db.add(OrderEvent(order_id=o.id, type="assigned_declined"))
    db.commit()
    events_bus.publish({"type": "order.assigned_declined", "order_id": o.id, "courier_id": courier_id})
    try:
        tokens = [t for (t,) in db.query(Device.token).all()]
        for t in tokens:
            send_silent(t, {"type": "order.assigned_declined", "order_id": o.id})
    except Exception:
        pass
    return {"ok": True}
