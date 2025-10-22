import { useEffect, useState } from 'react';
import { api } from '../libs/api';
import { withAuth } from '../libs/withAuth';
import { useRouter } from 'next/router';

type Order = { id: string | number; status: string; };

function Orders() {
  const router = useRouter();
  const [orders, setOrders] = useState<Order[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('token') : null;
    if (!token) {
      router.replace('/login');
      return;
    }
    api('orders')
      .then(setOrders)
      .catch(() => setError('Failed to load orders'));
  }, [router]);

  return (
    <div style={{ padding: 24 }}>
      <h1>Orders</h1>
      <div style={{ marginBottom: 16, display: 'flex', gap: 8 }}>
        <button onClick={() => router.push('/orders/new')}>New Order</button>
        <button onClick={() => { localStorage.removeItem('token'); router.push('/login'); }}>Logout</button>
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
