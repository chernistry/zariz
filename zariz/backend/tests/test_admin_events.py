"""Tests for admin SSE events endpoint."""
import json

from fastapi.testclient import TestClient

from app.services.events import events_bus
from app.core.security import create_access_token


def test_sse_requires_auth(client: TestClient):
    """SSE endpoint requires authentication."""
    resp = client.get("/v1/events/sse")
    assert resp.status_code == 401


def test_sse_admin_can_connect(client: TestClient):
    """Admin can connect to SSE endpoint."""
    admin_token = create_access_token(sub="1", role="admin")
    resp = client.get(f"/v1/events/sse?once=true&token={admin_token}")
    assert resp.status_code == 200
    assert "text/event-stream" in resp.headers["content-type"]


def test_sse_courier_can_connect(client: TestClient, courier_token: str):
    """Courier can connect to SSE endpoint."""
    resp = client.get(f"/v1/events/sse?once=true&token={courier_token}")
    assert resp.status_code == 200
    assert "text/event-stream" in resp.headers["content-type"]


def test_sse_store_can_connect(client: TestClient, store_token: str):
    """Store can connect to SSE endpoint."""
    resp = client.get(f"/v1/events/sse?once=true&token={store_token}")
    assert resp.status_code == 200
    assert "text/event-stream" in resp.headers["content-type"]


def test_order_created_event_includes_details(client: TestClient, store_token: str):
    """Order creation publishes event with order details."""
    # Subscribe to events
    q = events_bus.subscribe()
    
    try:
        # Create order
        resp = client.post(
            "/v1/orders",
            headers={"Authorization": f"Bearer {store_token}"},
            json={
                "pickup_address": "Warehouse A",
                "recipient_first_name": "John",
                "recipient_last_name": "Doe",
                "phone": "+1234567890",
                "street": "Main St",
                "building_no": "123",
                "boxes_count": 5,
            }
        )
        assert resp.status_code == 200
        order_id = resp.json()["id"]
        
        # Check event was published
        data = q.get_nowait()
        event = json.loads(data)
        assert event["type"] == "order.created"
        assert event["order_id"] == order_id
        assert event["pickup_address"] == "Warehouse A"
        assert "delivery_address" in event
        assert event["boxes_count"] == 5
        assert "created_at" in event
    finally:
        events_bus.unsubscribe(q)
