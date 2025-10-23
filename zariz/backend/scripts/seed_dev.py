#!/usr/bin/env python3
"""Seed development users and store:
- Courier user: phone='courier', password='12345678', role='courier'
- Store user: phone='shop', password='12345678', role='store', active, member of one store
"""
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.db.session import get_sessionmaker
from app.db.models.user import User
from app.db.models.store import Store
from app.db.models.store_user_membership import StoreUserMembership
from app.core.security import hash_password


def ensure_store(db: Session, name: str = "Dev Store") -> Store:
    st = db.execute(select(Store).where(Store.name == name)).scalars().first()
    if not st:
        st = Store(name=name, status="active", pickup_address="Main Warehouse")
        db.add(st)
        db.commit()
        db.refresh(st)
    return st


def ensure_user(db: Session, phone: str, name: str, role: str, password: str, status: str = "active") -> User:
    u = db.execute(select(User).where(User.phone == phone)).scalars().first()
    if not u:
        u = User(phone=phone, email=None, name=name, role=role, status=status, password_hash=hash_password(password))
        db.add(u)
        db.commit()
        db.refresh(u)
    else:
        # ensure active and password up to date
        u.status = status
        u.password_hash = hash_password(password)
        db.commit()
    return u


def main():
    SessionLocal = get_sessionmaker()
    db: Session = SessionLocal()
    try:
        # Store user and store
        store = ensure_store(db)
        shop = ensure_user(db, phone="shop", name="Shop User", role="store", password="12345678")
        # Membership
        m = db.execute(
            select(StoreUserMembership).where(StoreUserMembership.user_id == shop.id, StoreUserMembership.store_id == store.id)
        ).scalars().first()
        if not m:
            db.add(StoreUserMembership(user_id=shop.id, store_id=store.id, role_in_store="staff"))
        # Default store for convenience
        shop.default_store_id = store.id
        db.commit()

        # Courier user
        ensure_user(db, phone="courier", name="Courier User", role="courier", password="12345678")
        print("Seeded: shop / courier users and Dev Store")
    finally:
        db.close()


if __name__ == "__main__":
    main()

