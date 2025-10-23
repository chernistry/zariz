import { useEffect, useState } from 'react';
import { api, API_BASE } from '../libs/api';
import { withAuth } from '../libs/withAuth';
import { subscribe } from '../libs/sse';
import { useRouter } from 'next/router';
import { InputField } from '../components/InputField';
import { ButtonWithIcon } from '../components/ButtonWithIcon';
import { Button } from '../components/Button';
import AssignCourierDialog from '../components/modals/AssignCourierDialog';
import { Box, Button as MUIButton, MenuItem, Paper, Select, SelectChangeEvent, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, TextField, Typography } from '@mui/material';

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
    <Box sx={{ p: 3 }}>
      <Box sx={{ display:'flex', alignItems:'center', justifyContent:'space-between', mb: 2 }}>
        <Typography variant="h5">Orders</Typography>
        <Box sx={{ display:'flex', gap: 1 }}>
          <MUIButton variant="contained" onClick={() => router.push('/orders/new')}>New Order</MUIButton>
          <MUIButton variant="outlined" color="inherit" onClick={() => { localStorage.removeItem('token'); router.push('/login'); }}>Logout</MUIButton>
        </Box>
      </Box>

      <Box sx={{ display:'grid', gridTemplateColumns:'repeat(5, 1fr)', gap:1, mb: 2 }}>
        <Select size="small" value={filter.status} onChange={(e: SelectChangeEvent<string>)=>setFilter(f=>({...f, status:e.target.value}))} displayEmpty>
          <MenuItem value=''><em>All</em></MenuItem>
          <MenuItem value='new'>New</MenuItem>
          <MenuItem value='assigned'>Assigned</MenuItem>
          <MenuItem value='claimed'>Claimed</MenuItem>
          <MenuItem value='picked_up'>Picked up</MenuItem>
          <MenuItem value='delivered'>Delivered</MenuItem>
          <MenuItem value='canceled'>Canceled</MenuItem>
        </Select>
        <TextField size="small" label="Store ID" value={filter.store} onChange={(e)=>setFilter(f=>({...f, store:e.target.value}))} />
        <TextField size="small" label="Courier ID" value={filter.courier} onChange={(e)=>setFilter(f=>({...f, courier:e.target.value}))} />
        <TextField size="small" label="From (YYYY-MM-DD)" value={filter.from} onChange={(e)=>setFilter(f=>({...f, from:e.target.value}))} />
        <TextField size="small" label="To (YYYY-MM-DD)" value={filter.to} onChange={(e)=>setFilter(f=>({...f, to:e.target.value}))} />
      </Box>

      <Box sx={{ display:'flex', gap:1, mb: 1 }}>
        <MUIButton size="small" variant="outlined" onClick={exportCSV}>Export CSV</MUIButton>
      </Box>

      {error && <Typography color="error" variant="body2" sx={{ mb: 1 }}>{error}</Typography>}

      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Store</TableCell>
              <TableCell>Courier</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {orders.map(o => (
              <TableRow key={String(o.id)}>
                <TableCell>#{String(o.id)}</TableCell>
                <TableCell>{o.status === 'assigned' ? 'Awaiting acceptance' : o.status}</TableCell>
                <TableCell>{o.store_id ?? '-'}</TableCell>
                <TableCell>{o.courier_id ?? '-'}</TableCell>
                <TableCell>
                  <Box sx={{ display:'flex', gap: 1 }}>
                    <MUIButton size="small" onClick={()=>router.push(`/orders/${o.id}`)}>View</MUIButton>
                    <MUIButton size="small" onClick={()=>openAssign(o.id)}>Assign</MUIButton>
                    <MUIButton size="small" color="error" onClick={()=>openCancel(o.id)}>Cancel</MUIButton>
                  </Box>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      <AssignCourierDialog
        open={assignFor !== null}
        onClose={() => setAssignFor(null)}
        onSelect={selectCourier}
      />
    </Box>
  );
}

export default withAuth(Orders);
