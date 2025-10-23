import type { NextApiRequest, NextApiResponse } from 'next'

type Pair = { access_token: string; refresh_token: string }

const API_BASE = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000/v1'
const BASE_COOKIE_NAME = process.env.AUTH_COOKIE_NAME || 'zariz_refresh'

function isProd() { return process.env.NODE_ENV === 'production' }
function cookieName() { return isProd() ? `__Host-${BASE_COOKIE_NAME}` : BASE_COOKIE_NAME }

function serializeCookie(name: string, value: string, opts: { maxAgeSec?: number; path?: string; secure?: boolean; httpOnly?: boolean; sameSite?: 'Strict'|'Lax'|'None' }) {
  const parts = [ `${name}=${encodeURIComponent(value)}` ]
  parts.push(`Path=${opts.path || '/'}`)
  if (opts.httpOnly !== false) parts.push('HttpOnly')
  if (opts.secure !== false) parts.push('Secure')
  parts.push(`SameSite=${opts.sameSite || 'Strict'}`)
  if (opts.maxAgeSec) parts.push(`Max-Age=${opts.maxAgeSec}`)
  return parts.join('; ')
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method Not Allowed' })
  const { identifier, password } = req.body || {}
  if (typeof identifier !== 'string' || typeof password !== 'string' || !identifier || !password) {
    return res.status(400).json({ error: 'invalid_request', message: 'identifier/password required' })
  }
  try {
    const r = await fetch(`${API_BASE}/auth/login_password`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier, password })
    })
    if (!r.ok) {
      const text = await r.text().catch(() => '')
      return res.status(r.status).json({ error: 'login_failed', message: text || 'Invalid credentials' })
    }
    const data = await r.json() as Pair
    const name = cookieName()
    const cookie = serializeCookie(name, data.refresh_token, {
      httpOnly: true,
      secure: true,
      sameSite: 'Strict',
      maxAgeSec: 14 * 24 * 60 * 60,
      path: '/',
    })
    res.setHeader('Set-Cookie', cookie)
    // Do not return refresh token to client
    return res.status(200).json({ access_token: data.access_token })
  } catch (e) {
    return res.status(500).json({ error: 'server_error' })
  }
}

