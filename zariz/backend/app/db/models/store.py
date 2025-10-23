from typing import Optional
from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from ..base import Base


class Store(Base):
    __tablename__ = "stores"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(120), unique=True)
    # Optional fields for admin management (added via migration)
    status: Mapped[Optional[str]] = mapped_column(String(16), nullable=True)  # active/suspended
    pickup_address: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    box_limit: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    hours_text: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
