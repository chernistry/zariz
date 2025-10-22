from fastapi import APIRouter

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register")
def register_device():
    return {"ok": True}

