import * as React from 'react'
import { Box, Button, TextField, Typography } from '@mui/material'

export type Creds = { email?: string; phone?: string; password?: string }

type Props = {
  value: Creds
  onChange: (next: Creds) => void
  onSubmit: () => Promise<void>
  pending?: boolean
}

function randomPassword(len = 12): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%*'
  let out = ''
  for (let i=0;i<len;i++) out += alphabet[Math.floor(Math.random()*alphabet.length)]
  return out
}

export default function CredentialsBlock({ value, onChange, onSubmit, pending }: Props) {
  const [generated, setGenerated] = React.useState<string | null>(null)
  return (
    <Box sx={{ border: '1px solid #ddd', borderRadius: 1, p: 2, mt: 3 }}>
      <Typography variant="h6" gutterBottom>Credentials</Typography>
      <Box sx={{ display:'flex', flexDirection:'column', gap: 2 }}>
        <TextField fullWidth label="Email" value={value.email || ''} onChange={e=>onChange({ ...value, email: e.target.value })} placeholder="user@example.com" />
        <TextField fullWidth label="Phone" value={value.phone || ''} onChange={e=>onChange({ ...value, phone: e.target.value })} placeholder="+1 555 123 4567" />
        <Box sx={{ display:'flex', gap: 2 }}>
          <TextField fullWidth type="text" label="Temporary Password" value={value.password || generated || ''}
            onChange={e=>onChange({ ...value, password: e.target.value })}
            placeholder="Generate or enter a new password" />
          <Button variant="outlined" onClick={() => { const p = randomPassword(); setGenerated(p); onChange({ ...value, password: p }); }}>Generate</Button>
        </Box>
        <Button variant="contained" onClick={onSubmit} disabled={pending}>Save Credentials</Button>
        <Typography variant="body2" color="text.secondary">
          Password will be shown here once generated. Copy and share via a secure channel. Users must change it on first login (if supported).
        </Typography>
      </Box>
    </Box>
  )
}
