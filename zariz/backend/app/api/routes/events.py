from __future__ import annotations

import asyncio
from typing import AsyncGenerator

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

from ...services.events import events_bus
from ..deps import require_role


router = APIRouter(prefix="/events", tags=["events"])


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
    identity: dict = Depends(require_role("admin", "store", "courier"))
) -> StreamingResponse:
    """Server-Sent Events stream for real-time order updates.
    
    Requires authentication. Admin users receive all events.
    Store/courier users receive filtered events (future enhancement).
    """
    return StreamingResponse(
        _event_stream(once),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable Nginx buffering
        },
    )
