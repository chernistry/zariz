import { useEffect, useState } from 'react';
import { api, API_BASE } from '../libs/api';
import { withAuth } from '../libs/withAuth';
import { subscribe } from '../libs/sse';
import { useRouter } from 'next/router';
import { InputField } from '../components/InputField';
import { ButtonWithIcon } from '../components/ButtonWithIcon';
import { Button } from '../components/Button';
import AssignCourierDialog from '../components/modals/AssignCourierDialog';

type Order = { id: string | number; status: string; store_id?: number; courier_id?: number | null; created_at?: string };
type Filter = { status: string; store: string; courier: string; from: string; to: string };

function Orders() {
  const router = useRouter();
  const [orders, setOrders] = useState<Order[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>({ status: '', store: '', courier: '', from: '', to: '' });
  const [assignFor, setAssignFor] = useState<number | string | null>(null);

  async function refresh() {
    setError(null);
    try {
      const params = new URLSearchParams();
      Object.entries(filter).forEach(([k, v]) => { if (v) params.set(k, v) });
      const path = params.toString() ? `orders?${params}` : 'orders';
      const data = await api(path);
      setOrders(data);
    } catch {
      setError('Failed to load orders');
    }
  }

  useEffect(() => { refresh(); }, [filter]);
  useEffect(() => {
    const off = subscribe(`${API_BASE}/events/sse`, (msg: any) => {
      if (typeof msg?.type === 'string' && msg.type.startsWith('order.')) refresh();
    });
    return off;
  }, []);

  function exportCSV() {
    const header = ['id', 'status', 'store_id', 'courier_id', 'created_at'];
    const rows = orders.map(o => [o.id, o.status, o.store_id ?? '', o.courier_id ?? '', o.created_at ?? '']);
    const csv = [header, ...rows]
      .map(r => r.map(String).map(s => `"${s.replaceAll('"','""')}"`).join(','))
      .join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = 'orders.csv'; a.click(); URL.revokeObjectURL(url);
  }

  function openAssign(id: number | string) { setAssignFor(id); }
  async function selectCourier(courierId: number) {
    if (!assignFor) return;
    try {
      await api(`orders/${assignFor}/assign`, { method: 'POST', body: JSON.stringify({ courier_id: courierId }) });
      setAssignFor(null);
      await refresh();
    } catch (e) {
      setError('Failed to assign');
    }
  }

  function openCancel(id: number | string) {
    const reason = prompt('Cancel reason?') || '';
    api(`orders/${id}/cancel`, { method: 'POST', body: JSON.stringify({ reason }) })
      .then(refresh)
      .catch(() => setError('Failed to cancel'));
  }

  return (
    <div style={{ padding: 24 }}>
      <h1>Orders</h1>
      <div style={{ marginBottom: 16, display: 'flex', gap: 8 }}>
        <button onClick={() => router.push('/orders/new')}>New Order</button>
        <button onClick={() => { localStorage.removeItem('token'); router.push('/login'); }}>Logout</button>
      </div>
      <div style={{ display:'grid', gridTemplateColumns:'repeat(5, 1fr)', gap:8, marginBottom: 12 }}>
        <select value={filter.status} onChange={e=>setFilter(f=>({...f, status:e.target.value}))}>
          <option value=''>All</option>
          <option value='new'>New</option>
          <option value='assigned'>Assigned</option>
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

      {error && <div style={{ color: 'crimson' }}>{error}</div>}

      <table width="100%" cellPadding={8}>
        <thead><tr><th>ID</th><th>Status</th><th>Store</th><th>Courier</th><th>Actions</th></tr></thead>
        <tbody>
          {orders.map(o => (
            <tr key={o.id}>
              <td>#{String(o.id)}</td>
              <td>{o.status === 'assigned' ? 'Awaiting acceptance' : o.status}</td>
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

      <AssignCourierDialog
        open={assignFor !== null}
        onClose={() => setAssignFor(null)}
        onSelect={selectCourier}
      />
    </div>
  );
}

export default withAuth(Orders);
