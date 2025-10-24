import * as React from 'react'
import { Box, Button, MenuItem, TextField } from '@mui/material'
import type { StoreDTO } from '../../libs/api'

type Props = {
  value: StoreDTO
  onChange: (next: StoreDTO) => void
  onSubmit: () => Promise<void>
  pending?: boolean
}

export default function StoreForm({ value, onChange, onSubmit, pending }: Props) {
  return (
    <Box component="form" onSubmit={(e: React.FormEvent)=>{e.preventDefault(); onSubmit()}} sx={{ mt: 2, display:'flex', flexDirection:'column', gap: 2 }}>
      <Box sx={{ display:'flex', gap: 2, flexWrap:'wrap' }}>
        <TextField fullWidth required label="Store Name" value={value.name} onChange={e=>onChange({ ...value, name: e.target.value })} />
        <TextField select fullWidth label="Status" value={value.status || 'active'} onChange={e=>onChange({ ...value, status: e.target.value as any })}>
          <MenuItem value="active">active</MenuItem>
          <MenuItem value="suspended">suspended</MenuItem>
          <MenuItem value="offboarded">offboarded</MenuItem>
        </TextField>
      </Box>
      <TextField fullWidth label="Pickup Address" value={value.pickup_address || ''} onChange={e=>onChange({ ...value, pickup_address: e.target.value })} />
      <Box sx={{ display:'flex', gap: 2, flexWrap:'wrap' }}>
        <TextField type="number" fullWidth label="Box Limit" value={value.box_limit ?? ''} onChange={e=>onChange({ ...value, box_limit: e.target.value ? Number(e.target.value) : undefined })} />
        <TextField fullWidth label="Hours (text)" value={value.hours_text || ''} onChange={e=>onChange({ ...value, hours_text: e.target.value })} />
      </Box>
      <Button variant="contained" type="submit" disabled={pending}>Save</Button>
    </Box>
  )
}
