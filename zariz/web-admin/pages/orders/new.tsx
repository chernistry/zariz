import { useEffect, useState } from 'react';
import { api } from '../../libs/api';
import { useRouter } from 'next/router';

export default function NewOrder() {
  const router = useRouter();
  const [pickup_address, setPickup] = useState('');
  const [delivery_address, setDelivery] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('token') : null;
    if (!token) router.replace('/login');
  }, [router]);

  async function create(e?: React.FormEvent) {
    e?.preventDefault();
    setError(null);
    try {
      await api('orders', { method: 'POST', body: JSON.stringify({ pickup_address, delivery_address }) });
      router.push('/orders');
    } catch (err) {
      setError('Failed to create order');
    }
  }

  return (
    <div style={{ padding: 24 }}>
      <h1>New Order</h1>
      <form onSubmit={create} style={{ display: 'flex', flexDirection: 'column', gap: 12, width: 420 }}>
        <input value={pickup_address} onChange={e=>setPickup(e.target.value)} placeholder="Pickup address" />
        <input value={delivery_address} onChange={e=>setDelivery(e.target.value)} placeholder="Delivery address" />
        {error && <div style={{ color: 'crimson' }}>{error}</div>}
        <button type="submit">Create</button>
      </form>
    </div>
  );
}

