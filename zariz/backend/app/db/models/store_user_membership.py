from sqlalchemy import Integer, Boolean, String, ForeignKey, DateTime, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from ..base import Base


class StoreUserMembership(Base):
    __tablename__ = "store_user_memberships"
    __table_args__ = (
        UniqueConstraint("user_id", "store_id", name="uq_store_user_membership_user_store"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    store_id: Mapped[int] = mapped_column(ForeignKey("stores.id"), nullable=False)
    role_in_store: Mapped[str] = mapped_column(String(32), default="staff")
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

