from fastapi import APIRouter
from . import stores, couriers

admin_router = APIRouter(prefix="/admin", tags=["admin"])
admin_router.include_router(stores.router, prefix="/stores")
admin_router.include_router(couriers.router, prefix="/couriers")

