Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: Web realtime (SSE), list filters, UX polish

Objective
- Subscribe to backend SSE for live order updates in the store dashboard.
- Add filters by status/date and incremental refresh.

Deliverables
- SSE client on `/orders` page that updates table without reload.
- Filters and basic pagination.

Reference-driven accelerators (copy/adapt)
- From next-delivery:
  - Reuse component primitives (Header, InputField) for filters layout and consistent styling.
  - Use app-level context/store pattern to broadcast updates to orders list.

SSE client
```
// src/lib/sse.ts
export function subscribe(url: string, onData: (msg: any) => void) {
  const es = new EventSource(url)
  es.onmessage = (e) => {
    try { onData(JSON.parse(e.data)) } catch {}
  }
  return () => es.close()
}
```

Use in orders page
```
import { API_BASE } from '$lib/api'
import { subscribe } from '$lib/sse'
let orders: any[] = []
onMount(() => {
  const off = subscribe(`${API_BASE}/events/sse`, (msg) => {
    if (msg.type?.startsWith('order.')) refresh()
  })
  return () => off()
})
async function refresh() { /* fetch and update orders */ }
```

Filters
- Add select for status and date range; append query params on fetch.

Integrate in Next pages
```
// zariz/web-admin/pages/orders.tsx (augment)
import { useEffect, useState } from 'react';
import { API_BASE } from '../libs/api';
import { subscribe } from '../libs/sse';
export default function Orders() {
  const [orders, setOrders] = useState<any[]>([]);
  const [status, setStatus] = useState<string>('');
  async function refresh() {
    const url = new URL(`${API_BASE}/orders`);
    if (status) url.searchParams.set('status', status);
    const r = await fetch(url.toString()); setOrders(await r.json());
  }
  useEffect(() => { refresh(); }, [status]);
  useEffect(() => subscribe(`${API_BASE}/events/sse`, (msg)=>{ if (msg.type?.startsWith('order.')) refresh(); }), []);
  return (
    <div>
      <select value={status} onChange={e=>setStatus(e.target.value)}>
        <option value=''>All</option>
        <option value='new'>New</option>
        <option value='claimed'>Claimed</option>
        <option value='picked_up'>Picked up</option>
        <option value='delivered'>Delivered</option>
      </select>
      <ul>{orders.map(o => <li key={o.id}>#{o.id} • {o.status}</li>)}</ul>
    </div>
  );
}
```

Verification
- Create orders in web; see updates stream live.

Next
- E2E testing and contracts in Ticket 13.
