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
