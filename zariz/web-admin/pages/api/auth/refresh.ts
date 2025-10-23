import type { NextApiRequest, NextApiResponse } from 'next'

type Pair = { access_token: string; refresh_token: string }

const API_BASE = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000/v1'
const BASE_COOKIE_NAME = process.env.AUTH_COOKIE_NAME || 'zariz_refresh'
function isProd() { return process.env.NODE_ENV === 'production' }
function cookieName() { return isProd() ? `__Host-${BASE_COOKIE_NAME}` : BASE_COOKIE_NAME }

function parseCookie(header?: string | null): Record<string, string> {
  const out: Record<string, string> = {}
  if (!header) return out
  header.split(';').forEach(part => {
    const [k, ...rest] = part.trim().split('=')
    if (!k) return
    out[k] = decodeURIComponent(rest.join('='))
  })
  return out
}

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
  const cookies = parseCookie(req.headers.cookie)
  const name = cookieName()
  const refresh = cookies[name]
  if (!refresh) return res.status(401).json({ error: 'no_session' })
  try {
    const r = await fetch(`${API_BASE}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refresh })
    })
    if (!r.ok) {
      return res.status(r.status).json({ error: 'refresh_failed' })
    }
    const data = await r.json() as Pair
    const cookie = serializeCookie(name, data.refresh_token, {
      httpOnly: true,
      secure: true,
      sameSite: 'Strict',
      maxAgeSec: 14 * 24 * 60 * 60,
      path: '/',
    })
    res.setHeader('Set-Cookie', cookie)
    return res.status(200).json({ access_token: data.access_token })
  } catch (e) {
    return res.status(500).json({ error: 'server_error' })
  }
}

