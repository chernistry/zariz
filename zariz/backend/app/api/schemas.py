from typing import Optional, Literal
from pydantic import BaseModel, Field


class AuthLogin(BaseModel):
    subject: str = Field(..., description="User identifier for sub claim")
    role: Literal["courier", "store", "admin"]


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class OrderCreate(BaseModel):
    recipient_first_name: str
    recipient_last_name: str
    phone: str
    street: str
    building_no: str
    floor: Optional[str] = None
    apartment: Optional[str] = None
    boxes_count: int = Field(gt=0, le=200)
    pickup_address: Optional[str] = None
    delivery_address: Optional[str] = None
    store_id: Optional[int] = None


class OrderRead(BaseModel):
    id: int
    store_id: int
    courier_id: Optional[int] = None
    status: str
    pickup_address: str
    delivery_address: str
    recipient_first_name: Optional[str] = None
    recipient_last_name: Optional[str] = None
    phone: Optional[str] = None
    street: Optional[str] = None
    building_no: Optional[str] = None
    floor: Optional[str] = None
    apartment: Optional[str] = None
    boxes_count: Optional[int] = None
    boxes_multiplier: Optional[int] = None
    price_total: Optional[int] = None
    created_at: Optional[str] = None


class StatusUpdate(BaseModel):
    status: Literal["picked_up", "delivered", "canceled"]


class DeviceRegister(BaseModel):
    platform: Literal["ios"]
    token: str
