import os
import time
import uuid
from fastapi import FastAPI, Request
from starlette.middleware.cors import CORSMiddleware
from .api import api_router
from .core.limits import limiter
from .core.logging import setup_logging
from slowapi.middleware import SlowAPIMiddleware

setup_logging()
app = FastAPI(title="Zariz API", version="0.1.0")

origins = [o.strip() for o in os.getenv("CORS_ALLOW_ORIGINS", "http://localhost:3000").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rate limiting
app.state.limiter = limiter
app.add_middleware(SlowAPIMiddleware)

app.include_router(api_router, prefix="/v1")

# Request ID and latency logging
@app.middleware("http")
async def add_request_id_and_log(request: Request, call_next):
    req_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    start = time.perf_counter()
    response = await call_next(request)
    duration_ms = (time.perf_counter() - start) * 1000
    response.headers["X-Request-ID"] = req_id
    import logging as _logging

    _logging.getLogger("uvicorn.access").info(
        json_log(
            method=request.method,
            path=request.url.path,
            status_code=response.status_code,
            duration_ms=round(duration_ms, 2),
            request_id=req_id,
        )
    )
    return response


def json_log(**kwargs):
    import json as _json

    return _json.dumps(kwargs, ensure_ascii=False)

# Optional OpenTelemetry instrumentation
if os.getenv("OTEL_ENABLED"):
    try:
        from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

        FastAPIInstrumentor.instrument_app(app)
    except Exception:
        pass

# Optional Sentry
dsn = os.getenv("SENTRY_DSN")
if dsn:
    try:
        import sentry_sdk

        sentry_sdk.init(dsn=dsn, traces_sample_rate=float(os.getenv("SENTRY_TRACES_SAMPLE_RATE", "0.1")))
    except Exception:
        pass
