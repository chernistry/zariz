from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from ..base import Base


class Store(Base):
    __tablename__ = "stores"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(120), unique=True)

