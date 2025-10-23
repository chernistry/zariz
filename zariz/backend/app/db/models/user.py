from sqlalchemy import String, Integer, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from ..base import Base


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    phone: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(String(16), index=True)  # courier/store/admin
    status: Mapped[str] = mapped_column(String(16), default="disabled")  # active/disabled
    password_hash: Mapped[str] = mapped_column(String(255), default="!")
    default_store_id: Mapped[int | None] = mapped_column(ForeignKey("stores.id"), nullable=True)
    last_login_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    store_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    capacity_boxes: Mapped[int] = mapped_column(Integer, default=8)
