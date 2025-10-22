from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from .base import Base
from ..core.config import settings


engine = create_engine(settings.db_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def init_db() -> None:
    Base.metadata.create_all(bind=engine)

