import { useState } from 'react';
import { Box, TextField, Button, Typography, Alert, Paper, Container } from '@mui/material';
import { authClient } from '../libs/authClient';

export default function Login() {
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e?: React.FormEvent) {
    e?.preventDefault();
    if (!identifier || !password) { setError('Please enter email/phone and password'); return }
    setPending(true); setError(null);
    try {
      const r = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier, password })
      })
      if (!r.ok) throw new Error(String(r.status))
      const data = await r.json()
      const access_token = data?.access_token as string | undefined
      if (!access_token) throw new Error('No access token returned')
      try { localStorage.setItem('token', access_token) } catch {}
      authClient._set(access_token)
      location.href = '/orders'
    } catch (err) {
      setError('Login failed. Check your credentials or contact Zariz admin.')
    } finally {
      setPending(false)
    }
  }

  return (
    <Container maxWidth="xs">
      <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Paper elevation={3} sx={{ p: 4, width: '100%' }}>
          <Typography variant="h4" component="h1" gutterBottom align="center">
            Zariz Admin
          </Typography>
          <Box component="form" onSubmit={submit} sx={{ mt: 3 }}>
            <TextField
              fullWidth
              label="Email or Phone"
              value={identifier}
              onChange={e => setIdentifier(e.target.value)}
              autoComplete="username"
              autoCapitalize="none"
              margin="normal"
              disabled={pending}
            />
            <TextField
              fullWidth
              label="Password"
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              autoComplete="current-password"
              margin="normal"
              disabled={pending}
            />
            {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
            <Button
              fullWidth
              type="submit"
              variant="contained"
              size="large"
              disabled={pending}
              sx={{ mt: 3, mb: 2 }}
            >
              {pending ? 'Signing in…' : 'Sign In'}
            </Button>
            <Typography variant="caption" color="text.secondary" align="center" display="block">
              No self-service. For access, contact Zariz administrator.
            </Typography>
          </Box>
        </Paper>
      </Box>
    </Container>
  );
}
