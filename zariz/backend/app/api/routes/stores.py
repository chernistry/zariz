from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..deps import get_db, require_role
from ...db.models.store import Store

router = APIRouter()


@router.get("")
def list_stores(
    db: Session = Depends(get_db),
    identity: dict = Depends(require_role("admin", "store")),
):
    stores = db.query(Store).all()
    return [{"id": s.id, "name": s.name} for s in stores]
