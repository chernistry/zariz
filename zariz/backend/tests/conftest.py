import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.security import create_access_token
from app.db.base import Base
from app.db.models.store import Store
from app.db.models.order import Order
from app.api import deps as deps_module


TEST_DB_URL = "sqlite:///./_test.db"


@pytest.fixture(scope="session", autouse=True)
def _prepare_db_file():
    try:
        os.remove("_test.db")
    except FileNotFoundError:
        pass
    yield
    try:
        os.remove("_test.db")
    except FileNotFoundError:
        pass


@pytest.fixture()
def db_session():
    engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
    TestingSessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture()
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    # override dependency
    app.dependency_overrides[deps_module.get_db] = override_get_db
    if not db_session.query(Store).filter(Store.id == 1).first():
        db_session.add(Store(id=1, name="Test Store"))
        db_session.commit()
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture()
def store_token():
    return create_access_token(sub="1", role="store")


@pytest.fixture()
def courier_token():
    return create_access_token(sub="101", role="courier")


@pytest.fixture()
def seeded_order(db_session):
    import uuid
    st = Store(name=f"Test Store {uuid.uuid4()}")
    db_session.add(st)
    db_session.flush()
    o = Order(
        store_id=st.id,
        courier_id=None,
        status="new",
        pickup_address="A",
        delivery_address="Street 1",
        recipient_first_name="Test",
        recipient_last_name="User",
        phone="000",
        street="Street",
        building_no="1",
        floor="",
        apartment="",
        boxes_count=2,
        boxes_multiplier=1,
        price_total=35,
    )
    db_session.add(o)
    db_session.commit()
    return o.id
