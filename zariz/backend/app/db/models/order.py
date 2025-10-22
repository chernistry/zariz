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
    recipient_first_name: Mapped[str] = mapped_column(String(120))
    recipient_last_name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str] = mapped_column(String(40))
    street: Mapped[str] = mapped_column(String(180))
    building_no: Mapped[str] = mapped_column(String(30))
    floor: Mapped[str] = mapped_column(String(30), default="")
    apartment: Mapped[str] = mapped_column(String(30), default="")
    boxes_count: Mapped[int] = mapped_column(Integer, default=0)
    boxes_multiplier: Mapped[int] = mapped_column(Integer, default=1)
    price_total: Mapped[int] = mapped_column(Integer, default=0)
