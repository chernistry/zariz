from fastapi import APIRouter
from .routes import auth, orders, devices, events, couriers, stores
from .routes.admin import admin_router

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(orders.router)
api_router.include_router(stores.router)
api_router.include_router(devices.router)
api_router.include_router(events.router)
api_router.include_router(couriers.router)
api_router.include_router(admin_router)
