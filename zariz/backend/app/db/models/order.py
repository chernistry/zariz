from sqlalchemy import Integer, String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from ..base import Base


class Order(Base):
    __tablename__ = "orders"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    store_id: Mapped[int] = mapped_column(ForeignKey("stores.id"))
    courier_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    status: Mapped[str] = mapped_column(String(32), index=True)  # new/claimed/picked_up/delivered/canceled
    pickup_address: Mapped[str] = mapped_column(String(255))
    delivery_address: Mapped[str] = mapped_column(String(255))

