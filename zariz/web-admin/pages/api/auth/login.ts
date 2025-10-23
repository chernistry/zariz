import type { NextApiRequest, NextApiResponse } from 'next'

const BASES = [
  process.env.BACKEND_API_BASE,
  process.env.NEXT_PUBLIC_API_BASE,
  'http://backend:8000/v1',
  'http://localhost:8000/v1',
].filter(Boolean) as string[]
const LOGIN_PASSWORD_PATH = process.env.AUTH_LOGIN_PATH || '/auth/login_password'

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end()
  try {
    const { identifier, password } = req.body || {}
    if (!identifier || !password) return res.status(400).json({ code: 'bad_request', message: 'identifier and password required' })

    let lastErr: Response | null = null
    for (const base of BASES) {
      // Try password login first
      let r = await fetch(base + LOGIN_PASSWORD_PATH, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier, password })
      })
      if (r.ok) { const data = await r.json(); return res.status(200).json(data) }

      // Fallback to legacy stub login if available
      const legacy = await fetch(base + '/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subject: identifier, role: 'admin' })
      })
      if (legacy.ok) { const data = await legacy.json(); return res.status(200).json(data) }
      lastErr = legacy
    }
    if (lastErr) {
      const text = await lastErr.text().catch(() => '')
      return res.status(lastErr.status).send(text || 'Login failed')
    }
    return res.status(502).send('No backend available')
  } catch (err: any) {
    return res.status(500).send('Login proxy error')
  }
}
