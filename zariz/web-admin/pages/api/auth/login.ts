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
      const r = await fetch(base + LOGIN_PASSWORD_PATH, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier, password })
      })
      if (r.ok) {
        const data = await r.json()
        if (data && data.refresh_token) {
          const isProd = process.env.NODE_ENV === 'production'
          const maxAge = 60 * 60 * 24 * 14
          res.setHeader('Set-Cookie', `zariz_rt=${encodeURIComponent(data.refresh_token)}; Path=/; HttpOnly; SameSite=Strict; ${isProd ? 'Secure; ' : ''}Max-Age=${maxAge}`)
        }
        return res.status(200).json(data)
      }
      lastErr = r
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
