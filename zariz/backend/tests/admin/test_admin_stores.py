from app.core.security import create_access_token, verify_password
from app.db.models.user import User
from app.db.models.store import Store
from app.db.models.store_user_membership import StoreUserMembership


def auth_header(token: str):
    return {"Authorization": f"Bearer {token}"}


def test_admin_create_store_and_credentials(client, db_session):
    # Admin token
    token = create_access_token(sub="1", role="admin")
    # Create store
    r = client.post("/v1/admin/stores", headers=auth_header(token), json={"name": "MegaStore"})
    assert r.status_code == 200
    sid = r.json()["id"]
    # Set credentials (create primary store user)
    r2 = client.post(
        f"/v1/admin/stores/{sid}/credentials",
        headers=auth_header(token),
        json={"email": "store@mega.example.com", "password": "p@ssw0rd"},
    )
    assert r2.status_code == 200
    # Validate DB
    u = db_session.query(User).filter(User.email == "store@mega.example.com").first()
    assert u is not None
    assert u.role == "store"
    assert u.status == "active"
    # Membership exists
    m = db_session.query(StoreUserMembership).filter(StoreUserMembership.user_id == u.id, StoreUserMembership.store_id == sid).first()
    assert m is not None and m.is_primary is True
    assert verify_password("p@ssw0rd", u.password_hash)


def test_admin_store_status_and_update(client, db_session):
    token = create_access_token(sub="1", role="admin")
    s = Store(name="S0")
    db_session.add(s)
    db_session.commit()
    # Update name
    r = client.patch(f"/v1/admin/stores/{s.id}", headers=auth_header(token), json={"name": "S1X"})
    assert r.status_code == 200
    db_session.refresh(s)
    assert s.name == "S1X"
    # Set status if supported
    r2 = client.post(f"/v1/admin/stores/{s.id}/status", headers=auth_header(token), json={"status": "suspended"})
    # If model supports status, expect 200 and value updated; otherwise 400
    if r2.status_code == 200:
        db_session.refresh(s)
        assert getattr(s, "status", None) == "suspended"
    else:
        assert r2.status_code == 400


def test_non_admin_forbidden(client, db_session):
    token = create_access_token(sub="1", role="store")
    r = client.get("/v1/admin/stores", headers=auth_header(token))
    assert r.status_code == 403
