export const API_BASE = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000/v1';

export async function api(path: string, opts: RequestInit = {}) {
  const token = typeof window !== 'undefined' ? localStorage.getItem('token') : undefined;
  const headers = {
    'Content-Type': 'application/json',
    ...(opts.headers || {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  } as Record<string, string>;
  const res = await fetch(`${API_BASE}/${path}`, { ...opts, headers });
  if (!res.ok) throw new Error(String(res.status));
  return res.json();
}

