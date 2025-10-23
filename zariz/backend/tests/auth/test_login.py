from app.core.security import hash_password
from app.db.models.user import User
from app.db.models.store import Store
from app.db.models.store_user_membership import StoreUserMembership


def auth_header(token: str):
    return {"Authorization": f"Bearer {token}"}


def test_password_login_success(client, db_session):
    # Seed user
    u = User(email="admin@example.com", phone="+100000000", name="Admin", role="admin", status="active", password_hash=hash_password("s3cr3t"))
    db_session.add(u)
    db_session.commit()
    r = client.post("/v1/auth/login_password", json={"identifier": "admin@example.com", "password": "s3cr3t"})
    assert r.status_code == 200
    body = r.json()
    assert body.get("access_token") and body.get("refresh_token")


def test_password_login_failure(client, db_session):
    # Seed inactive user
    u = User(email="user@example.com", phone="+100000001", name="U", role="store", status="disabled", password_hash=hash_password("pass"))
    db_session.add(u)
    db_session.commit()
    r = client.post("/v1/auth/login_password", json={"identifier": "user@example.com", "password": "pass"})
    assert r.status_code == 401


def test_refresh_rotation(client, db_session):
    u = User(email="s@example.com", phone="+100000002", name="S", role="store", status="active", password_hash=hash_password("p") )
    db_session.add(u)
    st = Store(name="S1")
    db_session.add(st)
    db_session.flush()
    db_session.add(StoreUserMembership(user_id=u.id, store_id=st.id, role_in_store="staff"))
    db_session.commit()

    r = client.post("/v1/auth/login_password", json={"identifier": "s@example.com", "password": "p"})
    assert r.status_code == 200
    refresh = r.json()["refresh_token"]
    # Refresh
    r2 = client.post("/v1/auth/refresh", json={"refresh_token": refresh})
    assert r2.status_code == 200
    new_refresh = r2.json()["refresh_token"]
    assert new_refresh != refresh
    # Old refresh should be rejected now
    r3 = client.post("/v1/auth/refresh", json={"refresh_token": refresh})
    assert r3.status_code == 401

