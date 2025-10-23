from app.core.security import create_access_token, verify_password
from app.db.models.user import User


def auth_header(token: str):
    return {"Authorization": f"Bearer {token}"}


def test_admin_create_and_update_courier(client, db_session):
    token = create_access_token(sub="1", role="admin")
    # Create courier
    r = client.post(
        "/v1/admin/couriers",
        headers=auth_header(token),
        json={"name": "C1", "phone": "+15550001", "capacity_boxes": 12},
    )
    assert r.status_code == 200
    cid = r.json()["id"]
    u = db_session.get(User, cid)
    assert u is not None and u.role == "courier"
    assert u.capacity_boxes == 12
    # Update data
    r2 = client.patch(
        f"/v1/admin/couriers/{cid}",
        headers=auth_header(token),
        json={"capacity_boxes": 14, "status": "disabled"},
    )
    assert r2.status_code == 200
    db_session.refresh(u)
    assert u.capacity_boxes == 14
    assert u.status == "disabled"
    # Set credentials (email + password)
    r3 = client.post(
        f"/v1/admin/couriers/{cid}/credentials",
        headers=auth_header(token),
        json={"email": "c1@example.com", "password": "s3cr3t"},
    )
    assert r3.status_code == 200
    db_session.refresh(u)
    assert u.email == "c1@example.com"
    assert verify_password("s3cr3t", u.password_hash)


def test_admin_couriers_rbac(client, db_session):
    token = create_access_token(sub="1", role="courier")
    r = client.get("/v1/admin/couriers", headers=auth_header(token))
    assert r.status_code == 403

