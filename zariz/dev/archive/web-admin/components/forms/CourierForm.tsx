import * as React from 'react'
import { Box, Button, MenuItem, TextField } from '@mui/material'
import type { CourierDTO } from '../../libs/api'

type Props = {
  value: CourierDTO
  onChange: (next: CourierDTO) => void
  onSubmit: () => Promise<void>
  pending?: boolean
}

export default function CourierForm({ value, onChange, onSubmit, pending }: Props) {
  return (
    <Box component="form" onSubmit={(e: React.FormEvent)=>{e.preventDefault(); onSubmit()}} sx={{ mt: 2, display:'flex', flexDirection:'column', gap: 2 }}>
      <Box sx={{ display:'flex', gap: 2, flexWrap:'wrap' }}>
        <TextField fullWidth required label="Name" value={value.name} onChange={(e: React.ChangeEvent<HTMLInputElement>)=>onChange({ ...value, name: e.target.value })} />
        <TextField select fullWidth label="Status" value={value.status || 'active'} onChange={(e)=>onChange({ ...value, status: e.target.value as any })}>
          <MenuItem value="active">active</MenuItem>
          <MenuItem value="suspended">suspended</MenuItem>
          <MenuItem value="offboarded">offboarded</MenuItem>
        </TextField>
      </Box>
      <Box sx={{ display:'flex', gap: 2, flexWrap:'wrap' }}>
        <TextField fullWidth label="Email" value={value.email || ''} onChange={(e)=>onChange({ ...value, email: e.target.value })} />
        <TextField fullWidth label="Phone" value={value.phone || ''} onChange={(e)=>onChange({ ...value, phone: e.target.value })} />
      </Box>
      <TextField type="number" fullWidth label="Capacity (boxes)" value={value.capacity_boxes ?? 8} onChange={(e)=>onChange({ ...value, capacity_boxes: e.target.value ? Number(e.target.value) : undefined })} />
      <Button variant="contained" type="submit" disabled={pending}>Save</Button>
    </Box>
  )
}
