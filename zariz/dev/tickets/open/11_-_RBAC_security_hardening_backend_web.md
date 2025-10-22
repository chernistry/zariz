Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: RBAC + security hardening (backend + web)

Objective
- Enforce role-based access, object-level authorization, rate limits, and CORS.
- Secure cookies or token storage on web; sanitize inputs.

Deliverables — Backend
- `require_role` on routes; verify store can only see own orders.
- Add CORS middleware (domains allowlist).
- Rate limiting (e.g., slowapi) for write endpoints; standard 429 with Retry-After.
- Input validation with Pydantic models for requests.

Reference-driven accelerators (copy/adapt)
- From deliver-backend:
  - Mirror guard/role patterns from Nest: translate to FastAPI dependency-based RBAC (`require_role`) and per-resource checks.
  - Borrow configuration split (`src/config/*`) for environment-driven allowlists and secrets (JWT secret, CORS origins) — fold into `app/core/config.py`.
- From next-delivery:
  - Use contexts to keep auth state and inject Authorization header on the client; implement a simple route guard at page level (redirect to `/login` if no token).

Code snippets
```
# CORS
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(CORSMiddleware, allow_origins=["https://your.domain"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

# Pydantic
from pydantic import BaseModel, Field
class CreateOrder(BaseModel):
    pickup_address: str = Field(min_length=3, max_length=255)
    delivery_address: str = Field(min_length=3, max_length=255)

# Rate limiting (slowapi)
from slowapi import Limiter
from slowapi.util import get_remote_address
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
```

Deliverables — Web
- Use Authorization header from storage; on logout remove it.
- Escape outputs in templates; trust nothing from user input.
- Configure environment for API base URL; do not hardcode secrets.

Copy/Integrate (web)
```
# If next-delivery provides auth contexts/hooks, reuse them
ls zariz/web-admin/contexts || true
# Add a simple HOC for protecting pages
// zariz/web-admin/libs/withAuth.tsx
import { useEffect } from 'react';
export function withAuth<P>(Comp: React.ComponentType<P>) {
  return (props: P) => {
    useEffect(()=>{ if (!localStorage.getItem('token')) location.href='/login'; }, []);
    return <Comp {...props} />;
  }
}
```

Verification
- Attempt to access other-store orders → 403.
- Write bursts return 429.

Next
- Implement realtime SSE + filters in Ticket 12.

---

Analysis (agent)
- Mode: Execute. Harden backend and web auth.
- Backend already has JWT parsing and `require_role`; `GET /v1/orders` lacked role checks and leaked all orders.
- CORS exists (env `CORS_ALLOW_ORIGINS`). Rate limiting absent.
- Web now stores JWT in `localStorage` and uses Authorization header via `libs/api.ts` from Ticket 10.

Plan
- Backend
  - Add global rate limiter: slowapi `Limiter(key_func=get_remote_address)`; register `SlowAPIMiddleware` and `app.state.limiter`.
  - Guard `GET /v1/orders` with `require_role("store","admin","courier")` and apply object-level checks: store → own orders only; courier → own or `new`; admin → all.
  - Add per-route rate limits for write endpoints (`POST /orders`, `POST /orders/{id}/claim`, `POST /orders/{id}/status`).
  - Keep CORS env-driven allowlist.
- Web
  - Align login payload with backend: `{subject, role}`.
  - Add `withAuth` HOC to protect pages and implement Logout clearing token.
  - Ensure all API calls use Authorization header via `libs/api.ts`.
- Verification
  - Run backend tests (pytest) → expect green.
  - Smoke run web build.

Implementation (executed)
- Backend
  - Added `app/core/limits.py` with slowapi `limiter`.
  - Registered in `app/main.py`: `app.state.limiter = limiter`, `SlowAPIMiddleware`.
  - Secured `GET /v1/orders` with role dependency + object-level filters.
  - Added rate limits: `@limiter.limit("10/minute")` on create, `20/minute` on claim, `30/minute` on status.
  - Updated tests expecting auth on list: `zariz/backend/tests/test_core_apis.py`.
  - Added dependency `slowapi~=0.1` to `pyproject.toml` and reinstalled venv.
- Web
  - Updated `pages/login.tsx` to send `{subject, role}`.
  - Added `libs/withAuth.tsx`; wrapped `orders` and `orders/new` pages; added Logout button.

Verification (results)
- Backend: `.venv/bin/pytest -q` → 6 passed.
- Web: `zariz/web-admin` builds successfully (`yarn build`).
