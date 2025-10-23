import * as React from 'react';
import { withAuth } from '../libs/withAuth';
import { listCouriersAdmin, setCourierStatus, type CourierAdmin } from '../libs/api';
import { Box, Button, MenuItem, Paper, Select, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Typography } from '@mui/material';
import { useRouter } from 'next/router';

function Couriers() {
  const router = useRouter()
  const [rows, setRows] = React.useState<CourierAdmin[]>([]);
  const [status, setStatus] = React.useState<'all'|'active'|'suspended'|'offboarded'>('all');
  const [error, setError] = React.useState<string | null>(null);
  const [pendingId, setPendingId] = React.useState<number|undefined>()

  const load = React.useCallback(async () => {
    try {
      setError(null);
      const data = await listCouriersAdmin();
      setRows(data);
    } catch (e) {
      setError('Failed to load couriers');
    }
  }, []);

  React.useEffect(() => { load(); }, [load]);

  const filtered = rows.filter(r => status==='all' ? true : (r.status||'active')===status)

  async function changeStatus(id: number, next: 'active'|'suspended') {
    setPendingId(id)
    try { await setCourierStatus(id, next) } catch {} finally { setPendingId(undefined); load() }
  }

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display:'flex', alignItems:'center', justifyContent:'space-between', mb: 2 }}>
        <Typography variant="h5">Couriers</Typography>
        <Box sx={{ display:'flex', gap: 1 }}>
          <Select size="small" value={status} onChange={e=>setStatus(e.target.value as any)}>
            <MenuItem value="all">All</MenuItem>
            <MenuItem value="active">Active</MenuItem>
            <MenuItem value="suspended">Suspended</MenuItem>
            <MenuItem value="offboarded">Offboarded</MenuItem>
          </Select>
          <Button variant="contained" onClick={()=>router.push('/couriers/new')}>Create</Button>
        </Box>
      </Box>
      {error && <Typography color="error" variant="body2" sx={{ mb: 1 }}>{error}</Typography>}
      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Email</TableCell>
              <TableCell>Phone</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Capacity</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filtered.map((r) => (
              <TableRow key={r.id} hover>
                <TableCell>#{r.id}</TableCell>
                <TableCell>{r.name}</TableCell>
                <TableCell>{r.email || '-'}</TableCell>
                <TableCell>{r.phone || '-'}</TableCell>
                <TableCell>{r.status || 'active'}</TableCell>
                <TableCell>{r.capacity_boxes ?? '-'}</TableCell>
                <TableCell align="right">
                  <Button size="small" onClick={()=>router.push(`/couriers/${r.id}`)}>Edit</Button>
                  {(r.status||'active')==='active' ? (
                    <Button size="small" color="warning" disabled={pendingId===r.id} onClick={()=>changeStatus(r.id, 'suspended')}>Deactivate</Button>
                  ) : (
                    <Button size="small" color="success" disabled={pendingId===r.id} onClick={()=>changeStatus(r.id, 'active')}>Reactivate</Button>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}

export default withAuth(Couriers);
