from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass

# Import models so Alembic can autogenerate migrations
# (no runtime side-effects aside from table registration)
try:
    from .models import user, store, order, order_event, device, idempotency  # noqa: F401
except Exception:
    # During certain tooling runs, modules may not be importable; safe to ignore.
    pass
