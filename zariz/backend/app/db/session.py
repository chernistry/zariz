from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from .base import Base
from ..core.config import settings


def get_engine():
    return create_engine(settings.db_url, pool_pre_ping=True)


def get_sessionmaker():
    return sessionmaker(bind=get_engine(), autoflush=False, autocommit=False)


def init_db() -> None:
    Base.metadata.create_all(bind=get_engine())
