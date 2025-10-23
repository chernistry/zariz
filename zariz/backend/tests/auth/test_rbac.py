from app.core.security import create_access_token
from app.db.models.user import User
from app.db.models.store import Store
from app.db.models.store_user_membership import StoreUserMembership
from app.db.models.order import Order


def auth_header(token: str):
    return {"Authorization": f"Bearer {token}"}


def test_store_scoping_list_orders(client, db_session):
    # Create two stores
    s1 = Store(name="S10")
    s2 = Store(name="S20")
    db_session.add_all([s1, s2])
    db_session.flush()
    # Create orders in both stores
    o1 = Order(store_id=s1.id, courier_id=None, status="new", pickup_address="A", delivery_address="X", recipient_first_name="", recipient_last_name="", phone="", street="", building_no="", floor="", apartment="", boxes_count=1, boxes_multiplier=1, price_total=10)
    o2 = Order(store_id=s2.id, courier_id=None, status="new", pickup_address="A", delivery_address="Y", recipient_first_name="", recipient_last_name="", phone="", street="", building_no="", floor="", apartment="", boxes_count=1, boxes_multiplier=1, price_total=10)
    db_session.add_all([o1, o2])
    db_session.flush()
    # Create a store user with access to s1 only
    u = User(email="store1@example.com", phone="+1", name="S1", role="store", status="active", password_hash="!")
    db_session.add(u)
    db_session.flush()
    db_session.add(StoreUserMembership(user_id=u.id, store_id=s1.id, role_in_store="staff"))
    db_session.commit()
    # Issue token that includes store_ids claim
    token = create_access_token(sub=str(u.id), role="store", store_ids=[s1.id])
    r = client.get("/v1/orders", headers=auth_header(token))
    assert r.status_code == 200
    ids = {row["id"] for row in r.json()}
    assert o1.id in ids
    assert o2.id not in ids
