import json


def auth_header(token: str):
    return {"Authorization": f"Bearer {token}"}


def test_auth_login(client):
    r = client.post("/v1/auth/login", json={"subject": "1", "role": "store"})
    assert r.status_code == 200
    assert r.json()["access_token"]


def test_create_and_list_orders(client, store_token):
    # create
    payload = {
        "pickup_address": "Warehouse A",
        "recipient_first_name": "John",
        "recipient_last_name": "Doe",
        "phone": "+972500000000",
        "street": "Main",
        "building_no": "10",
        "floor": "2",
        "apartment": "5",
        "boxes_count": 4,
    }
    r = client.post(
        "/v1/orders",
        headers=auth_header(store_token) | {"Idempotency-Key": "abc-1"},
        json=payload,
    )
    assert r.status_code == 200
    order = r.json()
    assert order["boxes_count"] == 4
    assert order["boxes_multiplier"] == 1
    # repeat with same idem key returns cached
    r2 = client.post(
        "/v1/orders",
        headers=auth_header(store_token) | {"Idempotency-Key": "abc-1"},
        json=payload,
    )
    assert r2.status_code == 200
    assert r2.json()["id"] == order["id"]

    # list (requires auth; store sees its own orders)
    r = client.get("/v1/orders", headers=auth_header(store_token))
    assert r.status_code == 200
    assert any(o["id"] == order["id"] for o in r.json())


def test_idempotency_key_mismatch_cross_endpoint(client, store_token, courier_token):
    # Create an order with a specific key
    key = "reuse-key-1"
    payload = {
        "pickup_address": "Warehouse",
        "recipient_first_name": "Sara",
        "recipient_last_name": "Cohen",
        "phone": "+972500000111",
        "street": "Herzl",
        "building_no": "8",
        "boxes_count": 3,
    }
    r = client.post(
        "/v1/orders",
        headers=auth_header(store_token) | {"Idempotency-Key": key},
        json=payload,
    )
    assert r.status_code == 200
    oid = r.json()["id"]
    # Reuse the same key on a different endpoint should return 409
    r2 = client.post(
        f"/v1/orders/{oid}/claim",
        headers=auth_header(courier_token) | {"Idempotency-Key": key},
    )
    assert r2.status_code == 409


def test_atomic_claim(client, courier_token, seeded_order):
    oid = seeded_order
    r1 = client.post(f"/v1/orders/{oid}/claim", headers=auth_header(courier_token))
    r2 = client.post(f"/v1/orders/{oid}/claim", headers=auth_header(courier_token))
    assert r1.status_code == 200
    assert r2.status_code == 409


def test_status_transitions(client, courier_token, seeded_order):
    oid = seeded_order
    # claim first
    r = client.post(f"/v1/orders/{oid}/claim", headers=auth_header(courier_token))
    assert r.status_code == 200
    # picked_up
    r = client.post(
        f"/v1/orders/{oid}/status",
        headers=auth_header(courier_token) | {"Idempotency-Key": "k1"},
        json={"status": "picked_up"},
    )
    assert r.status_code == 200
    # delivered
    r = client.post(
        f"/v1/orders/{oid}/status",
        headers=auth_header(courier_token) | {"Idempotency-Key": "k2"},
        json={"status": "delivered"},
    )
    assert r.status_code == 200
