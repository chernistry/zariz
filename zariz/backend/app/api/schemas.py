from typing import Optional, Literal, List
from pydantic import BaseModel, Field


class AuthLogin(BaseModel):
    subject: str = Field(..., description="User identifier for sub claim (legacy demo)")
    role: Literal["courier", "store", "admin"]


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AuthLoginRequest(BaseModel):
    identifier: str = Field(..., description="Email or phone")
    password: str = Field(..., description="Password")


class AuthTokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshTokenRequest(BaseModel):
    refresh_token: str


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


# Admin schemas
class StoreCreate(BaseModel):
    name: str
    status: Optional[Literal["active", "suspended"]] = "active"
    pickup_address: Optional[str] = None
    box_limit: Optional[int] = Field(default=8, ge=1, le=1000)
    hours_text: Optional[str] = None


class StoreUpdate(BaseModel):
    name: Optional[str] = None
    status: Optional[Literal["active", "suspended"]] = None
    pickup_address: Optional[str] = None
    box_limit: Optional[int] = Field(default=None, ge=1, le=1000)
    hours_text: Optional[str] = None


class CourierCreate(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    capacity_boxes: Optional[int] = Field(default=8, ge=1, le=200)
    status: Optional[Literal["active", "disabled"]] = "active"


class CourierUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    capacity_boxes: Optional[int] = Field(default=None, ge=1, le=200)
    status: Optional[Literal["active", "disabled"]] = None


class CredentialsChange(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None


class StatusChange(BaseModel):
    status: Literal["active", "disabled", "suspended", "offboarded"]
