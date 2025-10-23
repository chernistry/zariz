import { useState } from 'react';
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
      const { access_token } = await r.json()
      authClient._set(access_token)
      location.href = '/orders'
    } catch (err) {
      setError('Login failed. Check your credentials or contact Zariz admin.')
    } finally {
      setPending(false)
    }
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh', alignItems: 'center', justifyContent: 'center' }}>
      <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 12, width: 360 }}>
        <h1>Zariz Admin Login</h1>
        <input value={identifier} onChange={e=>setIdentifier(e.target.value)} placeholder="Email or phone" autoComplete="username" />
        <input value={password} onChange={e=>setPassword(e.target.value)} placeholder="Password" type="password" autoComplete="current-password" />
        {error && <div style={{ color: 'crimson' }}>{error}</div>}
        <button type="submit" disabled={pending}>{pending ? 'Signing in…' : 'Sign In'}</button>
        <div style={{ fontSize: 12, color: '#666' }}>No self-service. For access, contact Zariz administrator.</div>
      </form>
    </div>
  );
}
