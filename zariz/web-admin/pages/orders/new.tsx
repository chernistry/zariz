import { useEffect, useState } from 'react';
import { api } from '../../libs/api';
import { withAuth } from '../../libs/withAuth';
import { useRouter } from 'next/router';

function NewOrder() {
  const router = useRouter();
  const [formData, setFormData] = useState({
    recipient_first_name: '',
    recipient_last_name: '',
    phone: '',
    street: '',
    building_no: '',
    floor: '',
    apartment: '',
    boxes_count: 1,
    pickup_address: '',
    delivery_address: '',
  });
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('token') : null;
    if (!token) router.replace('/login');
  }, [router]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: name === 'boxes_count' ? parseInt(value) || 1 : value
    }));
  };

  async function create(e?: React.FormEvent) {
    e?.preventDefault();
    setError(null);
    try {
      await api('orders', { method: 'POST', body: JSON.stringify(formData) });
      router.push('/orders');
    } catch (err) {
      setError('Failed to create order: ' + (err instanceof Error ? err.message : String(err)));
    }
  }

  return (
    <div style={{ padding: 24 }}>
      <h1>New Order</h1>
      <form onSubmit={create} style={{ display: 'flex', flexDirection: 'column', gap: 12, width: 420 }}>
        <input name="recipient_first_name" value={formData.recipient_first_name} onChange={handleChange} placeholder="First Name *" required />
        <input name="recipient_last_name" value={formData.recipient_last_name} onChange={handleChange} placeholder="Last Name *" required />
        <input name="phone" value={formData.phone} onChange={handleChange} placeholder="Phone *" required />
        <input name="street" value={formData.street} onChange={handleChange} placeholder="Street *" required />
        <input name="building_no" value={formData.building_no} onChange={handleChange} placeholder="Building Number *" required />
        <input name="floor" value={formData.floor} onChange={handleChange} placeholder="Floor" />
        <input name="apartment" value={formData.apartment} onChange={handleChange} placeholder="Apartment" />
        <input name="boxes_count" type="number" min="1" max="200" value={formData.boxes_count} onChange={handleChange} placeholder="Boxes Count *" required />
        <input name="pickup_address" value={formData.pickup_address} onChange={handleChange} placeholder="Pickup Address" />
        <input name="delivery_address" value={formData.delivery_address} onChange={handleChange} placeholder="Delivery Address" />
        {error && <div style={{ color: 'crimson' }}>{error}</div>}
        <button type="submit">Create</button>
      </form>
    </div>
  );
}

export default withAuth(NewOrder);
