import { useRouter } from 'next/router';
import { useEffect, useState } from 'react';
import { api, API_BASE } from '../../libs/api';
import { withAuth } from '../../libs/withAuth';
import { subscribe } from '../../libs/sse';
import { ButtonWithIcon } from '../../components/ButtonWithIcon';

function OrderDetail() {
  const router = useRouter();
  const { id } = router.query as { id?: string };
  const [order, setOrder] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    if (!id) return;
    try { setOrder(await api(`orders/${id}`)); setError(null); } catch { setError('Failed to load'); }
  }

  useEffect(() => { load(); }, [id]);
  useEffect(() => {
    if (!id) return;
    const off = subscribe(`${API_BASE}/events/sse`, (msg: any) => {
      if (typeof msg?.type === 'string' && msg.type.startsWith('order.') && String(msg.order_id) === String(id)) load();
    });
    return off;
  }, [id]);

  async function assign(courier_id: number) {
    await api(`orders/${id}/assign`, { method: 'POST', body: JSON.stringify({ courier_id }) });
    await load();
  }
  async function cancel(reason: string) {
    await api(`orders/${id}/cancel`, { method: 'POST', body: JSON.stringify({ reason }) });
    await load();
  }

  if (!order) return <div style={{ padding:24 }}>Loading...</div>;
  return (
    <div style={{ padding:24 }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between' }}>
        <h1>Order #{order.id}</h1>
        <div style={{ display:'flex', gap:8 }}>
          <ButtonWithIcon color="#0a6" leftIcon="checked" value="Assign" onClick={()=>{
            const s = prompt('Courier ID?'); if (s) assign(parseInt(s,10));
          }} />
          <ButtonWithIcon color="#c33" leftIcon="delete" value="Cancel" onClick={()=>{
            const reason = prompt('Reason?') || ''; cancel(reason);
          }} />
        </div>
      </div>
      {error && <div style={{ color:'crimson' }}>{error}</div>}
      <div style={{ marginTop:12 }}>
        <div>Status: {order.status}</div>
        <div>Store: {order.store_id}</div>
        <div>Courier: {order.courier_id ?? '-'}</div>
        <div>Recipient: {[order.recipient_first_name, order.recipient_last_name].filter(Boolean).join(' ')}</div>
        <div>Phone: {order.phone}</div>
        <div>Address: {order.delivery_address}</div>
        <div>Boxes: {order.boxes_count}</div>
        <div>Price: ₪{order.price_total}</div>
      </div>
    </div>
  );
}

export default withAuth(OrderDetail);

