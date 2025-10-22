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
        yield f"data: {{\"ping\": {i}}}\n\n"
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

Next
- CI/CD and deployment in Ticket 5.
