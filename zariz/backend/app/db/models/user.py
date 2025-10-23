from sqlalchemy import String, Integer
from sqlalchemy.orm import Mapped, mapped_column
from ..base import Base


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    phone: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(String(16), index=True)  # courier/store/admin
    store_id: Mapped[int | None]
    capacity_boxes: Mapped[int] = mapped_column(Integer, default=8)
