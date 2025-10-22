import os
from fastapi import FastAPI
from starlette.middleware.cors import CORSMiddleware
from .api import api_router

app = FastAPI(title="Zariz API", version="0.1.0")

origins = [o.strip() for o in os.getenv("CORS_ALLOW_ORIGINS", "http://localhost:3000").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/v1")
