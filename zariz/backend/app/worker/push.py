from __future__ import annotations

import base64
import json
import logging
import os
import tempfile
import urllib.error
import urllib.request
from typing import Any, Dict

logger = logging.getLogger(__name__)


class _APNsClientWrapper:
    def __init__(self) -> None:
        self._client = None
        self._topic = os.getenv("APNS_TOPIC")
        key_path = os.getenv("APNS_KEY_PATH")
        key_inline = os.getenv("APNS_KEY_TEXT") or os.getenv("APNS_KEY_BASE64")
        team_id = os.getenv("APNS_TEAM_ID")
        key_id = os.getenv("APNS_KEY_ID")
        use_sandbox = os.getenv("APNS_USE_SANDBOX", "1").lower() not in {"0", "false", "no"}

        if not key_path and key_inline:
            try:
                tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".p8")
                try:
                    decoded = base64.b64decode(key_inline.encode("utf-8"))
                except Exception:
                    decoded = key_inline.encode("utf-8")
                tmp.write(decoded)
                tmp.flush()
                key_path = tmp.name
                logger.info("APNs inline key material loaded into %s", key_path)
            except Exception as exc:
                logger.warning("Failed to materialize inline APNs key: %s", exc)
                key_path = None

        if key_path and team_id and key_id and self._topic:
            try:
                from apns2.client import APNsClient  # type: ignore

                self._client = APNsClient(
                    key_path,
                    use_sandbox=use_sandbox,
                    team_id=team_id,
                    key_id=key_id,
                )
            except Exception as exc:  # pragma: no cover - optional dependency not required in tests
                logger.warning("APNs client not initialized: %s", exc)
        else:
            logger.info("APNs credentials not configured; push is a no-op")

    def send_silent(self, token: str, data: Dict[str, Any]) -> None:
        if not self._client or not self._topic:
            logger.debug("No-op APNs send_silent to %s: %s", token[:8] + "…", data)
            return
        try:
            from apns2.payload import Payload  # type: ignore

            payload = Payload(content_available=True, custom=data)
            self._client.send_notification(
                token,
                payload,
                topic=self._topic,
                push_type="background",
                priority=5,
            )
        except Exception as exc:  # pragma: no cover
            logger.warning("APNs send failed: %s", exc)


class _PushClient:
    def __init__(self) -> None:
        self._gorush_url = os.getenv("GORUSH_URL")
        self._gorush_topic = os.getenv("GORUSH_TOPIC") or os.getenv("APNS_TOPIC", "")
        self._gorush_platform = int(os.getenv("GORUSH_PLATFORM", "1"))
        self._gorush_timeout = float(os.getenv("GORUSH_TIMEOUT", "5"))
        self._gorush_production = os.getenv("GORUSH_SANDBOX", "true").lower() in {"0", "false", "no"}

        if self._gorush_url:
            logger.info("Push client configured to use gorush at %s", self._gorush_url)
            self._apns: _APNsClientWrapper | None = None
        else:
            self._apns = _APNsClientWrapper()

    def send_silent(self, token: str, data: Dict[str, Any]) -> None:
        if self._gorush_url:
            self._send_gorush(token, data)
            return
        if not self._apns:
            self._apns = _APNsClientWrapper()
        if self._apns:
            self._apns.send_silent(token, data)

    def _send_gorush(self, token: str, data: Dict[str, Any]) -> None:
        payload = {
            "notifications": [
                {
                    "platform": self._gorush_platform,
                    "tokens": [token],
                    "topic": self._gorush_topic,
                    "production": self._gorush_production,
                    "message": "",
                    "sound": "",
                    "push_type": "background",
                    "content_available": True,
                    "badge": 0,
                    "custom": data,
                }
            ]
        }
        body = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            self._gorush_url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=self._gorush_timeout) as resp:
                if resp.status >= 400:
                    logger.warning("gorush responded with status %s", resp.status)
        except urllib.error.URLError as exc:
            logger.warning("gorush send failed: %s", exc)


client = _PushClient()


def send_silent(token: str, data: Dict[str, Any]) -> None:
    """Send a background (content-available) push."""
    client.send_silent(token, data)
