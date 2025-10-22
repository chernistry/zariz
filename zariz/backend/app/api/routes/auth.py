from fastapi import APIRouter
from ...core.security import create_access_token
from ..schemas import AuthLogin, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(payload: AuthLogin):
    token = create_access_token(sub=str(payload.subject), role=payload.role)
    return TokenResponse(access_token=token)
