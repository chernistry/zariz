import { useState } from 'react';
import { api } from '../libs/api';

export default function Login() {
  const [login, setLogin] = useState('');
  const [error, setError] = useState<string | null>(null);

  async function submit(e?: React.FormEvent) {
    e?.preventDefault();
    setError(null);
    try {
      const r = await api('auth/login', { method: 'POST', body: JSON.stringify({ login }) });
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
        <input value={login} onChange={e=>setLogin(e.target.value)} placeholder="Phone or Email" />
        {error && <div style={{ color: 'crimson' }}>{error}</div>}
        <button type="submit">Sign In</button>
      </form>
    </div>
  );
}

