import { useState } from 'react';
import { api } from '../libs/api';

export default function Login() {
  const [subject, setSubject] = useState('');
  const [role, setRole] = useState<'store' | 'courier' | 'admin'>('store');
  const [error, setError] = useState<string | null>(null);

  async function submit(e?: React.FormEvent) {
    e?.preventDefault();
    setError(null);
    try {
      const r = await api('auth/login', { method: 'POST', body: JSON.stringify({ subject, role }) });
      if (r && r.access_token) {
        localStorage.setItem('token', r.access_token);
        location.href = '/orders';
      } else {
        setError('Invalid response');
      }
    } catch (err) {
      setError('Login failed');
    }
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh', alignItems: 'center', justifyContent: 'center' }}>
      <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 12, width: 320 }}>
        <h1>Zariz Admin Login</h1>
        <input value={subject} onChange={e=>setSubject(e.target.value)} placeholder="User/Store ID" />
        <select value={role} onChange={e=>setRole(e.target.value as any)}>
          <option value="store">Store</option>
          <option value="courier">Courier</option>
          <option value="admin">Admin</option>
        </select>
        {error && <div style={{ color: 'crimson' }}>{error}</div>}
        <button type="submit">Sign In</button>
      </form>
    </div>
  );
}
