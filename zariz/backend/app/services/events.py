import asyncio
import json
from typing import Any, Dict, Set


class EventBus:
    """A simple in-memory pub/sub for server-sent events.

    - Subscribers receive dictionaries; SSE route formats as JSON lines.
    - Thread-safe publish via loop.call_soon_threadsafe to support sync endpoints.
    """

    def __init__(self) -> None:
        self._subscribers: Set[asyncio.Queue] = set()
        self._loop: asyncio.AbstractEventLoop | None = None

    def _ensure_loop(self) -> asyncio.AbstractEventLoop | None:
        if self._loop is None:
            try:
                self._loop = asyncio.get_running_loop()
            except RuntimeError:
                # No running loop in this thread; will try again on publish from within ASGI context.
                self._loop = None
        return self._loop

    def subscribe(self) -> asyncio.Queue:
        q: asyncio.Queue = asyncio.Queue()
        self._subscribers.add(q)
        # Try to capture loop in case it's available now
        self._ensure_loop()
        return q

    def unsubscribe(self, q: asyncio.Queue) -> None:
        self._subscribers.discard(q)

    def publish(self, event: Dict[str, Any]) -> None:
        """Publish an event to all subscribers.

        Can be called from sync code. Uses call_soon_threadsafe to put_nowait into queues.
        """
        loop = self._ensure_loop()
        # Format once to avoid repeating work
        data = json.dumps(event)

        def _deliver() -> None:
            # Remove any closed/garbage queues opportunistically if they raise
            dead: list[asyncio.Queue] = []
            for q in list(self._subscribers):
                try:
                    q.put_nowait(data)
                except Exception:
                    dead.append(q)
            for q in dead:
                self._subscribers.discard(q)

        if loop is not None:
            loop.call_soon_threadsafe(_deliver)
        else:
            # If no loop known, attempt best-effort synchronous delivery (for tests)
            _deliver()


events_bus = EventBus()

