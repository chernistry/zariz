import { useEffect, useState } from 'react';
import { api, API_BASE } from '../libs/api';
import { withAuth } from '../libs/withAuth';
import { subscribe } from '../libs/sse';
import { useRouter } from 'next/router';

type Order = { id: string | number; status: string; };

function Orders() {
  const router = useRouter();
  const [orders, setOrders] = useState<Order[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<string>('');

  async function refresh() {
    setError(null);
    try {
      const path = status ? `orders?status=${encodeURIComponent(status)}` : 'orders';
      const data = await api(path);
      setOrders(data);
    } catch {
      setError('Failed to load orders');
    }
  }

  useEffect(() => { refresh(); }, [status]);
  useEffect(() => {
    const off = subscribe(`${API_BASE}/events/sse`, (msg: any) => {
      if (typeof msg?.type === 'string' && msg.type.startsWith('order.')) refresh();
    });
    return off;
  }, []);

  return (
    <div style={{ padding: 24 }}>
      <h1>Orders</h1>
      <div style={{ marginBottom: 16, display: 'flex', gap: 8 }}>
        <button onClick={() => router.push('/orders/new')}>New Order</button>
        <button onClick={() => { localStorage.removeItem('token'); router.push('/login'); }}>Logout</button>
      </div>
      <div style={{ marginBottom: 16 }}>
        <label>Status: </label>
        <select value={status} onChange={e=>setStatus(e.target.value)}>
          <option value=''>All</option>
          <option value='new'>New</option>
          <option value='claimed'>Claimed</option>
          <option value='picked_up'>Picked up</option>
          <option value='delivered'>Delivered</option>
          <option value='canceled'>Canceled</option>
        </select>
      </div>
      {error && <div style={{ color: 'crimson' }}>{error}</div>}
      <ul>
        {orders.map(o => (
          <li key={o.id}>#{String(o.id)} • {o.status}</li>
        ))}
      </ul>
    </div>
  );
}

export default withAuth(Orders);
