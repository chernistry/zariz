Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: Notifications — APNs worker, device registry, SSE for web

Objective
- Register iOS devices and send silent pushes on order events.
- Provide SSE endpoint for store/admin dashboard realtime updates.

Deliverables
- `/v1/devices/register` upsert storing `{user_id, platform=ios, token}`.
- Background worker to send APNs pushes (e.g., apns2) on `order.created`, `order.claimed`, `order.status_changed`.
- SSE endpoint `/v1/events/sse` streaming server-sent events for web panel.

Reference-driven accelerators (copy/adapt)
- food-delivery-ios-app (Backend/Push):
  - Review `Backend/index.js` for event-to-push wiring and message shape. Adopt the idea of small payloads with `content-available=1` and minimal keys (e.g., `{type:"order.created", order_id}`) for our APNs worker. Do not copy Node runtime.
- next-delivery (Web):
  - Use as inspiration for client-side subscription and state updates. We will implement native SSE consumption later in Ticket 12.
- deliver-backend:
  - None specific to push; keep module separation discipline (split worker from API module).

Device registration
```
# zariz/backend/app/api/routes/devices.py (replace/extend)
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ...db.session import SessionLocal

router = APIRouter(prefix="/devices", tags=["devices"])

def get_db():
    db = SessionLocal();
    try: yield db
    finally: db.close()

@router.post("/register")
def register_device(token: str, platform: str = "ios", db: Session = Depends(get_db)):
    # upsert by token
    db.execute(
        """INSERT INTO devices (user_id, platform, token) VALUES (NULL, :platform, :token)
             ON CONFLICT (token) DO UPDATE SET platform = excluded.platform""",
        {"platform": platform, "token": token},
    )
    db.commit()
    return {"ok": True}
```

APNs worker (sketch)
```
# zariz/backend/app/worker/push.py
from apns2.client import APNsClient
from apns2.payload import Payload
import os

CLIENT = APNsClient(os.getenv("APNS_KEY_PATH"), use_sandbox=True, team_id=os.getenv("APNS_TEAM_ID"), key_id=os.getenv("APNS_KEY_ID"))

def send_silent(token: str, data: dict):
    payload = Payload(content_available=True, custom=data)
    CLIENT.send_notification(token, payload, topic=os.getenv("APNS_TOPIC"))
```
Emit events in API after state changes (orders.py). For MVP, call `send_silent` inline; later move to RQ/Celery.

SSE endpoint
```
# zariz/backend/app/api/routes/events.py
from fastapi import APIRouter
from fastapi.responses import StreamingResponse
import asyncio

router = APIRouter(prefix="/events", tags=["events"])

async def event_stream():
    # MVP: simple in-memory queue; replace with Redis pubsub later
    for i in range(5):
        yield f"data: {\"ping\": {i}}\n\n"
        await asyncio.sleep(5)

@router.get("/sse")
async def sse():
    return StreamingResponse(event_stream(), media_type="text/event-stream")
```
Include router in `api/__init__.py`.

Config
- APNs requires: `APNS_KEY_PATH`, `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_TOPIC`.
- For sandbox test before iOS integration, keep worker callable but stubbed if no keys.

Verification
- Curl SSE endpoint and confirm event stream.
- Call device register and verify device row in DB.

---

Analysis
- Requirements: maintain a device registry, emit events for order lifecycle changes, expose SSE endpoint for the web admin. APNs worker should be callable without keys (no-op if unset).
- Reuse: keep worker separated under `app/worker`, and an in-memory event bus for SSE under `app/services` (will swap for Redis later).

Plan
- SSE
  - Add `app/services/events.py` with a simple in-memory `EventBus` (publish/subscribe queues).
  - Add `app/api/routes/events.py` with `GET /v1/events/sse` that streams:
    - Initial comment line `:ok` then heartbeat lines; supports `?once=1` for tests.
  - Wire router in `app/api/__init__.py`.
- APNs worker
  - Add `app/worker/push.py` with a wrapper around `apns2` (optional dep). No-op if env missing.
- Emit notifications
  - In `app/api/routes/orders.py`, after order create/claim/status update: publish SSE event and iterate device tokens to call `send_silent`.
- Config
  - Extend `.env.example` with `APNS_KEY_PATH`, `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_TOPIC`.
- Verification
  - Unit test: request `/v1/events/sse?once=1` and assert `:ok` present to avoid blocking.
  - Run existing core API tests to ensure no regressions.

Implementation Summary (paths changed)
- Added: `zariz/backend/app/services/events.py`
- Added: `zariz/backend/app/api/routes/events.py`
- Updated: `zariz/backend/app/api/__init__.py` (include events router)
- Updated: `zariz/backend/app/api/routes/orders.py` (publish SSE + APNs no-op send)
- Added: `zariz/backend/app/worker/push.py`
- Updated: `.env.example` (APNs vars)
- Added test: `zariz/backend/tests/test_events.py`

How to Verify (local)
- Backend tests
  - `cd zariz/backend && python3 -m venv .venv && source .venv/bin/activate`
  - `pip install -e . && pip install pytest httpx`
  - `pytest -q` → expect `5 passed`.
- SSE smoke
  - `uvicorn app.main:app --reload` and in another shell:
  - `curl -N http://localhost:8000/v1/events/sse` → see `:ok` and periodic `:hb` comments.
  - Or single-shot: `curl -s http://localhost:8000/v1/events/sse?once=1` → contains `:ok`.
- Device register
  - `curl -X POST http://localhost:8000/v1/devices/register -H 'Content-Type: application/json' -d '{"platform":"ios","token":"demo-token-1"}'`
  - Expect `{ "ok": true }` and a row in `devices` table.

Notes
- APNs is a no-op unless `APNS_*` env vars are set; safe for dev and CI.
- Event delivery uses an in-memory bus and will not fan out across processes; plan to replace with Redis pub/sub in a later ticket.
- Push targeting is broad for MVP (all devices). Will narrow by role/user later.

Status
- Implemented and verified locally with tests. Ready to mark as complete.

Next
- CI/CD and deployment in Ticket 5.

