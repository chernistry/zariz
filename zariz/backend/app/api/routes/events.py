from __future__ import annotations

import asyncio
from typing import AsyncGenerator, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from jose import JWTError, jwt

from ...core.config import settings
from ...services.events import events_bus


router = APIRouter(prefix="/events", tags=["events"])


def get_identity_from_token(token: Optional[str] = Query(None)) -> dict:
    """Extract identity from query parameter token for SSE (EventSource doesn't support headers)."""
    if not token:
        raise HTTPException(status_code=401, detail="Missing token")
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algo])
        role = payload.get("role")
        sub = payload.get("sub")
        if not role or not sub:
            raise HTTPException(status_code=401, detail="Invalid token")
        return {"role": role, "sub": sub, "store_ids": payload.get("store_ids")}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")


async def _event_stream(once: bool) -> AsyncGenerator[bytes, None]:
    q = events_bus.subscribe()
    try:
        # Send initial comment to establish the stream
        yield b":ok\n\n"
        if once:
            return
        while True:
            try:
                data: str = await asyncio.wait_for(q.get(), timeout=25)
                yield f"data: {data}\n\n".encode("utf-8")
            except asyncio.TimeoutError:
                # Heartbeat to keep connections alive through proxies
                yield b":hb\n\n"
    finally:
        events_bus.unsubscribe(q)


@router.get("/sse")
async def sse(
    once: bool = False,
    identity: dict = Depends(get_identity_from_token)
) -> StreamingResponse:
    """Server-Sent Events stream for real-time order updates.
    
    Requires authentication via query parameter token (EventSource doesn't support headers).
    Admin users receive all events. Store/courier users receive filtered events (future).
    """
    # Verify role
    role = identity.get("role")
    if role not in ("admin", "store", "courier"):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    
    return StreamingResponse(
        _event_stream(once),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable Nginx buffering
        },
    )
