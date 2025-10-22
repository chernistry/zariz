Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: Web panel scaffold (Next.js/TS), auth, routes

Objective
- Scaffold a Next.js TypeScript admin panel from the reference repo to let stores/admins create and monitor orders.
- Implement login form, protected routes, and minimal pages.

Deliverables
- Next.js project under `zariz/web-admin` created by copying from `next-delivery` and pruning storefront specifics.
- Pages: `/login`, `/orders`, `/orders/new`.
- API client module for Zariz API with Authorization header support.

Reference-driven accelerators (copy/adapt)
- From next-delivery:
  - Copy the entire repo into `zariz/web-admin` as a starting point, then remove tenant/storefront pages.
  - Keep `components`, `libs`, `contexts/auth` (if present) and reuse layout primitives (Header, InputField, Button).
  - Replace `pages` with our minimal set and wire auth context to store JWT from backend login.

Copy/Scaffold
```
rm -rf zariz/web-admin
cp -R zariz/references/next-delivery zariz/web-admin
rm -rf zariz/web-admin/.git

# Prune storefront-specific routes, keep only our admin pages
rm -rf zariz/web-admin/pages/[tenant]
mkdir -p zariz/web-admin/pages
```

API client
```
// zariz/web-admin/libs/api.ts
export const API_BASE = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000/v1';

export async function api(path: string, opts: RequestInit = {}) {
  const token = typeof window !== 'undefined' ? localStorage.getItem('token') : undefined;
  const headers = {
    'Content-Type': 'application/json',
    ...(opts.headers || {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  } as Record<string, string>;
  const res = await fetch(`${API_BASE}/${path}`, { ...opts, headers });
  if (!res.ok) throw new Error(String(res.status));
  return res.json();
}
```

Routes
```
// zariz/web-admin/pages/login.tsx
import { useState } from 'react';
import { api } from '../libs/api';
export default function Login() {
  const [login, setLogin] = useState('');
  async function submit() {
    const r = await api('auth/login', { method: 'POST', body: JSON.stringify({ login }) });
    localStorage.setItem('token', r.access_token);
    location.href = '/orders';
  }
  return (
    <div>
      <input value={login} onChange={e=>setLogin(e.target.value)} placeholder="Phone or Email" />
      <button onClick={submit}>Sign In</button>
    </div>
  )
}

// zariz/web-admin/pages/orders.tsx
import { useEffect, useState } from 'react';
import { API_BASE } from '../libs/api';
export default function Orders() {
  const [orders, setOrders] = useState<any[]>([]);
  useEffect(() => { fetch(`${API_BASE}/orders`).then(r=>r.json()).then(setOrders); }, []);
  return <ul>{orders.map(o => <li key={o.id}>#{o.id} • {o.status}</li>)}</ul>;
}

// zariz/web-admin/pages/orders/new.tsx
import { useState } from 'react';
import { api } from '../../libs/api';
export default function NewOrder() {
  const [pickup_address, setPickup] = useState('');
  const [delivery_address, setDelivery] = useState('');
  async function create() {
    await api('orders', { method: 'POST', body: JSON.stringify({ pickup_address, delivery_address }) });
    location.href = '/orders';
  }
  return (
    <div>
      <input value={pickup_address} onChange={e=>setPickup(e.target.value)} placeholder="Pickup" />
      <input value={delivery_address} onChange={e=>setDelivery(e.target.value)} placeholder="Delivery" />
      <button onClick={create}>Create Order</button>
    </div>
  )
}
```

Verification
- `cd zariz/web-admin && yarn && yarn dev`, visit `/login`, then create an order at `/orders/new`.

Next
- RBAC and security hardening in Ticket 11.

---

Analysis (agent)
- Mode: Execute. Lowest open ticket is 10.
- Goal: Scaffold `zariz/web-admin` from `zariz/references/next-delivery` (Next.js 12 + TS), prune storefront routes, add minimal admin pages: `/login`, `/orders`, `/orders/new`.
- Auth: Store JWT in `localStorage` (web); attach `Authorization: Bearer <token>` in API client.
- Backend base URL: expose via `NEXT_PUBLIC_API_BASE` (default `http://localhost:8000/v1`). Aligns with backend docs using `/v1/*`.
- Reuse: keep `components`, `styles`, `contexts/auth`, `libs` from reference; replace `pages` with our minimal set.
- Best practices fit: simple client-side auth, env-driven base URL, no secrets in logs, protected navigation after login.

Plan (commands and file ops)
1) Copy scaffold
   - `rm -rf zariz/web-admin`
   - `cp -R zariz/references/next-delivery zariz/web-admin`
   - `rm -rf zariz/web-admin/.git`
2) Prune storefront routes
   - `rm -rf zariz/web-admin/pages/[tenant]`
   - Ensure `zariz/web-admin/pages` exists
3) API client
   - Add `zariz/web-admin/libs/api.ts` (env: `NEXT_PUBLIC_API_BASE`, token from `localStorage`)
4) Pages
   - Add `zariz/web-admin/pages/login.tsx`
   - Add `zariz/web-admin/pages/orders.tsx`
   - Add `zariz/web-admin/pages/orders/new.tsx`
5) Verification (local)
   - `cd zariz/web-admin && yarn && yarn build && yarn dev`
   - Open `/login` → login → redirected to `/orders`
   - Create order via `/orders/new` and see it in list (requires backend running; if missing, smoke-test page renders)

Notes
- Ticket 11 will enforce RBAC and stronger guards; here we keep minimal auth redirect.
- If Yarn missing, use `npm i && npm run dev`.

---

Implementation (executed)
- Copied scaffold: `zariz/references/next-delivery` → `zariz/web-admin`; removed inner `.git`.
- Pruned storefront routes: removed `zariz/web-admin/pages/[tenant]`.
- Replaced landing: `zariz/web-admin/pages/index.tsx` now redirects to `/login` or `/orders` based on token.
- Added API client: `zariz/web-admin/libs/api.ts` with `NEXT_PUBLIC_API_BASE` and `Authorization` header.
- Added pages:
  - `zariz/web-admin/pages/login.tsx`
  - `zariz/web-admin/pages/orders.tsx`
  - `zariz/web-admin/pages/orders/new.tsx`

Verification (results)
- Ran: `cd zariz/web-admin && yarn install && yarn build` → build succeeded.
- Next.js pages present: `/login`, `/orders`, `/orders/new`, index redirects to the appropriate page.
- Note: Full API flows require backend running at `http://localhost:8000/v1` or set `NEXT_PUBLIC_API_BASE`.
