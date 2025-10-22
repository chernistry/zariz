from __future__ import annotations

import logging
import os
from typing import Any, Dict

logger = logging.getLogger(__name__)


class _APNsClientWrapper:
    def __init__(self) -> None:
        self._client = None
        self._topic = os.getenv("APNS_TOPIC")
        key_path = os.getenv("APNS_KEY_PATH")
        team_id = os.getenv("APNS_TEAM_ID")
        key_id = os.getenv("APNS_KEY_ID")
        if key_path and team_id and key_id and self._topic:
            try:
                from apns2.client import APNsClient  # type: ignore
                # sandbox by default for MVP
                self._client = APNsClient(
                    key_path,
                    use_sandbox=True,
                    team_id=team_id,
                    key_id=key_id,
                )
            except Exception as e:  # pragma: no cover - optional dependency not required in tests
                logger.warning("APNs client not initialized: %s", e)
        else:
            logger.info("APNs credentials not configured; push is a no-op")

    def send_silent(self, token: str, data: Dict[str, Any]) -> None:
        if not self._client or not self._topic:
            logger.debug("No-op APNs send_silent to %s: %s", token[:8] + "…", data)
            return
        try:
            from apns2.payload import Payload  # type: ignore

            payload = Payload(content_available=True, custom=data)
            self._client.send_notification(token, payload, topic=self._topic)
        except Exception as e:  # pragma: no cover
            logger.warning("APNs send failed: %s", e)


client = _APNsClientWrapper()


def send_silent(token: str, data: Dict[str, Any]) -> None:
    """Send a background (content-available) push. No-op if APNs not configured."""
    client.send_silent(token, data)

