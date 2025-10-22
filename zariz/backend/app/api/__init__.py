from fastapi import APIRouter
from .routes import auth, orders, devices

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(orders.router)
api_router.include_router(devices.router)

