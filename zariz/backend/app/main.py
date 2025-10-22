from fastapi import FastAPI
from .api import api_router

app = FastAPI(title="Zariz API")
app.include_router(api_router, prefix="/v1")

