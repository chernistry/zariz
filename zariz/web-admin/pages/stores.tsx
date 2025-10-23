import * as React from 'react'
import { withAuth } from '../libs/withAuth'
import { Box, Button, MenuItem, Paper, Select, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Typography } from '@mui/material'
import { listStores, setStoreStatus, type Store } from '../libs/api'
import { useRouter } from 'next/router'

function StoresPage() {
  const router = useRouter()
  const [rows, setRows] = React.useState<Store[]>([])
  const [status, setStatus] = React.useState<'all'|'active'|'suspended'|'offboarded'>('all')
  const [error, setError] = React.useState<string|null>(null)
  const [pendingId, setPendingId] = React.useState<number|undefined>()

  const load = React.useCallback(async () => {
    try {
      setError(null)
      const data = await listStores()
      setRows(data)
    } catch { setError('Failed to load stores') }
  }, [])

  React.useEffect(() => { load() }, [load])

  const filtered = rows.filter(r => status==='all' ? true : (r.status||'active')===status)

  async function changeStatus(id: number, next: 'active'|'suspended') {
    setPendingId(id)
    try { await setStoreStatus(id, next) } catch {} finally { setPendingId(undefined); load() }
  }

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display:'flex', alignItems:'center', justifyContent:'space-between', mb: 2 }}>
        <Typography variant="h5">Stores</Typography>
        <Box sx={{ display:'flex', gap: 1 }}>
          <Select size="small" value={status} onChange={e=>setStatus(e.target.value as any)}>
            <MenuItem value="all">All</MenuItem>
            <MenuItem value="active">Active</MenuItem>
            <MenuItem value="suspended">Suspended</MenuItem>
            <MenuItem value="offboarded">Offboarded</MenuItem>
          </Select>
          <Button variant="contained" onClick={()=>router.push('/stores/new')}>Create</Button>
        </Box>
      </Box>
      {error && <Typography color="error" variant="body2" sx={{ mb: 1 }}>{error}</Typography>}
      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Box limit</TableCell>
              <TableCell>Pickup address</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {filtered.map(s => (
              <TableRow key={s.id} hover>
                <TableCell>#{s.id}</TableCell>
                <TableCell>{s.name}</TableCell>
                <TableCell>{s.status || 'active'}</TableCell>
                <TableCell>{s.box_limit ?? '-'}</TableCell>
                <TableCell>{s.pickup_address || '-'}</TableCell>
                <TableCell align="right">
                  <Button size="small" onClick={()=>router.push(`/stores/${s.id}`)}>Edit</Button>
                  {(s.status||'active')==='active' ? (
                    <Button size="small" color="warning" disabled={pendingId===s.id} onClick={()=>changeStatus(s.id, 'suspended')}>Deactivate</Button>
                  ) : (
                    <Button size="small" color="success" disabled={pendingId===s.id} onClick={()=>changeStatus(s.id, 'active')}>Reactivate</Button>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  )
}

export default withAuth(StoresPage)

