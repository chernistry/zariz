Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

# [TICKET-3] Admin Web — Assign/Cancel, Advanced Filters, and CSV Export (reuse components from references/next-delivery)

Goal
- Implement administrative actions in the web-admin: assign courier, cancel order (admin-only), advanced list filters (status/date/store/courier), a simple CSV export for the filtered set (NOTE: user asked “not HTML but CSS” — assumed CSV); reuse UI components from `references/next-delivery` where beneficial.

Context and Rationale
- meeting.md: Admin assigns couriers and performs cancellations; stores do not cancel or confirm deliveries. Admin needs filters by status/date/store/courier and an export. best_practices.md: SSE for admin web is acceptable; keep it simple. tech_task.md: must be aligned to admin-centric operations; store-creation moves to iPad.

Deliverables
1) Backend endpoints for assign and cancel with RBAC and auditing
2) Web-admin UI for list filters and order details page with actions
3) CSV export of current filter result
4) Reuse of visual components (buttons, icons, inputs, header/sidebar) from `references/next-delivery` where missing
5) tech_task.md updates to reflect roles, RBAC, cancellation policy, export, and removal of store-facing web creation

Implementation Plan (Backend)
1. RBAC and Auditing
- Enforce roles: Store → only own orders; Courier → only assigned; Admin → all.
- Maintain `order_events` journal entries: `order.assigned`, `order.canceled` with actor and timestamp.

2. Endpoints
```http
POST /v1/orders/{id}/assign { courier_id: int }
POST /v1/orders/{id}/cancel { reason: string }
```

FastAPI example:
```python
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/v1/orders", tags=["orders"])

class AssignReq(BaseModel):
    courier_id: int

class CancelReq(BaseModel):
    reason: str

@router.post("/{order_id}/assign", status_code=204)
async def assign_order(order_id: int, req: AssignReq, user=Depends(auth_admin)):
    # check order exists & status==new; set courier_id and status 'claimed' or keep 'new' + assign table
    # insert order_events with type='order.assigned'
    return

@router.post("/{order_id}/cancel", status_code=204)
async def cancel_order(order_id: int, req: CancelReq, user=Depends(auth_admin)):
    # set status='canceled'; insert order_events with reason
    return
```

Implementation Plan (Web-admin)
0. Reuse from references/next-delivery (copy if missing; otherwise diff and align)
- Components to consider copying from `zariz/references/next-delivery/components` → `zariz/web-admin/components`:
  - `Button/` (styled button)
  - `ButtonWithIcon/` (useful for action buttons)
  - `Icon/` with SVGs (ensure `next.config.js` has `@svgr/webpack` — already present)
  - `InputField/` and `SearchInput/` (filters and dialogs)
  - `Header/` and `Sidebar/` + `SidebarMenuItem/` (optional, for layout polish)
- Styles (if helpful):
  - `references/next-delivery/styles/Order-id.module.css` → adapt as `web-admin/styles/Order-id.module.css` for a status ribbon/progress style on order details.

Suggested copy commands (run from repo root; adjust if files already exist):
```bash
cp -R zariz/references/next-delivery/components/ButtonWithIcon zariz/web-admin/components/
cp -R zariz/references/next-delivery/components/Icon zariz/web-admin/components/
cp -R zariz/references/next-delivery/components/InputField zariz/web-admin/components/
cp -R zariz/references/next-delivery/components/SearchInput zariz/web-admin/components/
cp -R zariz/references/next-delivery/components/Header zariz/web-admin/components/
cp -R zariz/references/next-delivery/components/Sidebar zariz/web-admin/components/
cp -R zariz/references/next-delivery/components/SidebarMenuItem zariz/web-admin/components/
cp zariz/references/next-delivery/styles/Order-id.module.css zariz/web-admin/styles/
```

1. Orders list: filters, actions and CSV export
- File: `zariz/web-admin/pages/orders.tsx`
- Add filter controls for status/date/store/courier and action buttons for “View”, “Assign”, “Cancel”, “Export CSV”. Keep existing SSE subscription to refresh data on `order.*`.

Code snippet (essential parts):
```tsx
// pages/orders.tsx (diff-like snippet)
import { InputField } from '../components/InputField'
import { Button } from '../components/Button'
import { ButtonWithIcon } from '../components/ButtonWithIcon'

type Filter = { status: string; store: string; courier: string; from: string; to: string };

function Orders() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [filter, setFilter] = useState<Filter>({ status: '', store: '', courier: '', from: '', to: '' });

  async function refresh() {
    const params = new URLSearchParams();
    Object.entries(filter).forEach(([k, v]) => { if (v) params.set(k, v) });
    const path = params.toString() ? `orders?${params}` : 'orders';
    const data = await api(path);
    setOrders(data);
  }

  useEffect(() => { refresh(); }, [filter]);

  function exportCSV() {
    const header = ['id','status','store_id','courier_id','created_at']
    const rows = orders.map(o => [o.id, o.status, o.store_id ?? '', o.courier_id ?? '', o.created_at ?? ''])
    const csv = [header, ...rows].map(r => r.map(String).map(s => `"${s.replaceAll('"','""')}"`).join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url; a.download = 'orders.csv'; a.click(); URL.revokeObjectURL(url)
  }

  return (
    <div style={{ padding: 24 }}>
      <h1>Orders</h1>
      <div style={{ display:'grid', gridTemplateColumns:'repeat(5, 1fr)', gap:8, marginBottom: 12 }}>
        <select value={filter.status} onChange={e=>setFilter(f=>({...f, status:e.target.value}))}>
          <option value=''>All</option>
          <option value='new'>New</option>
          <option value='claimed'>Claimed</option>
          <option value='picked_up'>Picked up</option>
          <option value='delivered'>Delivered</option>
          <option value='canceled'>Canceled</option>
        </select>
        <InputField color="#6A7D8B" placeholder="Store ID" value={filter.store} onChange={(v)=>setFilter(f=>({...f, store:v}))} />
        <InputField color="#6A7D8B" placeholder="Courier ID" value={filter.courier} onChange={(v)=>setFilter(f=>({...f, courier:v}))} />
        <InputField color="#6A7D8B" placeholder="From (YYYY-MM-DD)" value={filter.from} onChange={(v)=>setFilter(f=>({...f, from:v}))} />
        <InputField color="#6A7D8B" placeholder="To (YYYY-MM-DD)" value={filter.to} onChange={(v)=>setFilter(f=>({...f, to:v}))} />
      </div>

      <div style={{ marginBottom: 8, display:'flex', gap:8 }}>
        <Button color="#333" label="Export CSV" onClick={exportCSV} />
      </div>

      <table width="100%" cellPadding={8}>
        <thead><tr><th>ID</th><th>Status</th><th>Store</th><th>Courier</th><th>Actions</th></tr></thead>
        <tbody>
          {orders.map(o => (
            <tr key={o.id}>
              <td>#{String(o.id)}</td>
              <td>{o.status}</td>
              <td>{o.store_id ?? '-'}</td>
              <td>{o.courier_id ?? '-'}</td>
              <td style={{ display:'flex', gap:6 }}>
                <ButtonWithIcon color="#444" leftIcon="rightArrow" value="View" onClick={()=>router.push(`/orders/${o.id}`)} />
                <ButtonWithIcon color="#0a6" leftIcon="checked" value="Assign" onClick={()=>openAssign(o.id)} />
                <ButtonWithIcon color="#c33" leftIcon="delete" value="Cancel" onClick={()=>openCancel(o.id)} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

2. Order details page with actions (new file)
- Create `zariz/web-admin/pages/orders/[id].tsx`.
- Use visual ideas from `references/next-delivery/pages/[tenant]/order/[orderid].tsx` (status banner/progress). Remove tenant SSR and frontApi mocks; fetch via `libs/api.ts`.

Essential skeleton:
```tsx
import { useRouter } from 'next/router'
import { useEffect, useState } from 'react'
import { api } from '../../libs/api'
import { withAuth } from '../../libs/withAuth'
import { subscribe } from '../../libs/sse'
import { ButtonWithIcon } from '../../components/ButtonWithIcon'

function OrderDetail() {
  const router = useRouter()
  const { id } = router.query
  const [order, setOrder] = useState<any>(null)

  async function load() { if (id) setOrder(await api(`orders/${id}`)) }
  useEffect(() => { load() }, [id])
  useEffect(() => subscribe(`${process.env.NEXT_PUBLIC_API_BASE}/events/sse`, (msg:any)=>{
    if (msg?.type?.startsWith('order.') && String(msg.order_id) === String(id)) load()
  }), [id])

  async function assign(courier_id: number) {
    await api(`orders/${id}/assign`, { method: 'POST', body: JSON.stringify({ courier_id }) })
    await load()
  }
  async function cancel(reason: string) {
    await api(`orders/${id}/cancel`, { method: 'POST', body: JSON.stringify({ reason }) })
    await load()
  }

  if (!order) return <div style={{ padding:24 }}>Loading...</div>
  return (
    <div style={{ padding:24 }}>
      <h1>Order #{order.id}</h1>
      <div style={{ marginBottom:12 }}>Status: {order.status}</div>
      <div style={{ display:'flex', gap:8 }}>
        <ButtonWithIcon color="#0a6" leftIcon="checked" value="Assign" onClick={()=>{
          const s = prompt('Courier ID?'); if (s) assign(parseInt(s,10))
        }} />
        <ButtonWithIcon color="#c33" leftIcon="delete" value="Cancel" onClick={()=>{
          const reason = prompt('Reason?') || ''; cancel(reason)
        }} />
      </div>
    </div>
  )
}

export default withAuth(OrderDetail)
```

3. Clean login/role references
- In `zariz/web-admin/pages/login.tsx`, remove “store” option to match meeting.md (store acts on iPad). Keep Admin and possibly Courier for test purposes.

4. Notes on “stealing” from next-delivery
- If components already exist in `web-admin/components`, keep local versions. Otherwise, copy the folders listed above. They are simple TSX + CSS + SVG and work under our `next.config.js` (already loads `@svgr/webpack`).
- The `Order-id.module.css` file provides a useful visual for progress/status. Adapt class names or drop if not needed.

Documentation Updates
- `zariz/dev/tech_task.md`: reflect admin-only cancel, add assign operation, list filters, CSV export for orders, and clarify no store-facing creation in web-admin. Update RBAC examples consistent with coding_rules.

Acceptance Criteria
- Admin can assign a courier and cancel an order from web-admin. Non-admin cannot see these actions.
- Orders list supports filters by status/date/store/courier, and exporting the current view to CSV file downloads `orders.csv`.
- Details page reflects live changes via SSE and provides “Assign” and “Cancel” actions.
- Components reused from `references/next-delivery` compile and render with our Next config.

Implementation Summary (done)
- Backend:
  - Added `GET /v1/orders/{id}` for details.
  - Added admin-only `POST /v1/orders/{id}/assign` and `POST /v1/orders/{id}/cancel` with auditing via `order_events` and SSE publishes. File: `zariz/backend/app/api/routes/orders.py`.
  - Expanded list filters: `status`, `store`, `courier`, `from`, `to`; plus `created_at` field added to the model and response. Files: `zariz/backend/app/db/models/order.py`, `zariz/backend/app/api/schemas.py`, `zariz/backend/app/api/routes/orders.py`.
  - Tests remain green: `zariz/backend/.venv/bin/pytest` → 7 passed.
- Web-admin:
  - Orders list (`zariz/web-admin/pages/orders.tsx`): added filter controls (status/date/store/courier), action buttons (View/Assign/Cancel), and CSV export.
  - Order details page: new file `zariz/web-admin/pages/orders/[id].tsx` with live SSE refresh and Assign/Cancel actions.
  - Login role options cleaned: removed Store from `zariz/web-admin/pages/login.tsx`.
  - Components reused from `components/` (already present from references).

Verify
- Backend: run locally (Docker or `uvicorn`); test endpoints with admin JWT. Check SSE `/v1/events/sse` emits on assign/cancel.
- Web-admin: `cd zariz/web-admin && yarn dev` then navigate to `/orders`. Apply filters, export CSV, open detail, use Assign/Cancel. SSE should refresh lists automatically.

Notes
- Date filters accept `YYYY-MM-DD` ISO; time bounds are inclusive on `created_at`.
