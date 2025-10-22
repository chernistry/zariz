from typing import Optional, Literal
from pydantic import BaseModel, Field


class AuthLogin(BaseModel):
    subject: str = Field(..., description="User identifier for sub claim")
    role: Literal["courier", "store", "admin"]


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class OrderCreate(BaseModel):
    store_id: int
    pickup_address: str
    delivery_address: str


class OrderRead(BaseModel):
    id: int
    store_id: int
    courier_id: Optional[int] = None
    status: str
    pickup_address: str
    delivery_address: str


class StatusUpdate(BaseModel):
    status: Literal["picked_up", "delivered", "canceled"]


class DeviceRegister(BaseModel):
    platform: Literal["ios"]
    token: str

