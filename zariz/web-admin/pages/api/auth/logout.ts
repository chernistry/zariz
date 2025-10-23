import type { NextApiRequest, NextApiResponse } from 'next'

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

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method Not Allowed' })
  const cookies = parseCookie(req.headers.cookie)
  const name = cookieName()
  const refresh = cookies[name]
  try {
    if (refresh) {
      await fetch(`${API_BASE}/auth/logout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh_token: refresh })
      })
    }
  } catch {}
  // Clear cookie
  res.setHeader('Set-Cookie', `${name}=; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=0`)
  return res.status(200).json({ ok: true })
}

