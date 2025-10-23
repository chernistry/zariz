/* Lightweight in-memory auth client for web-admin
 * - Stores access token in memory only
 * - Schedules refresh when <2 minutes remain
 * - Proxies login/refresh/logout via Next.js API routes
 */

type Claims = {
  sub?: string
  role?: string
  exp?: number
  store_ids?: number[]
  session_id?: string
  [k: string]: unknown
}

type Subscriber = (token: string | null, claims: Claims | null) => void

let accessToken: string | null = null
let claims: Claims | null = null
let refreshTimer: ReturnType<typeof setTimeout> | null = null
const REFRESH_ENABLED = process.env.NEXT_PUBLIC_AUTH_REFRESH === '1'
let backoffMs = 0
const MAX_BACKOFF = 60_000
const BASE_BACKOFF = 1_000
const JITTER = 250

function base64UrlToBase64(input: string) {
  // Replace URL-safe chars and pad
  input = input.replace(/-/g, '+').replace(/_/g, '/');
  const pad = input.length % 4;
  if (pad) input += '='.repeat(4 - pad);
  return input;
}

function parseJwt(token: string): Claims | null {
  try {
    const [, payload] = token.split('.')
    const json = atob(base64UrlToBase64(payload))
    return JSON.parse(json)
  } catch {
    return null
  }
}

const subscribers = new Set<Subscriber>()
function notify() {
  subscribers.forEach((cb) => {
    try { cb(accessToken, claims) } catch {}
  })
}

function clearTimer() {
  if (refreshTimer) { clearTimeout(refreshTimer); refreshTimer = null }
}

function scheduleRefresh() {
  if (!REFRESH_ENABLED) return
  clearTimer()
  if (!claims?.exp) return
  const nowSec = Math.floor(Date.now() / 1000)
  // aim to refresh 120s before expiry
  const lead = 120
  let delayMs = Math.max(0, (claims.exp - nowSec - lead) * 1000)
  // If already within window, attempt soon
  if (delayMs === 0) delayMs = 250
  refreshTimer = setTimeout(async () => {
    try {
      await authClient.refresh()
      // reset backoff on success
      backoffMs = 0
    } catch {
      // exponential backoff with small jitter
      backoffMs = Math.min(MAX_BACKOFF, backoffMs === 0 ? BASE_BACKOFF : backoffMs * 2)
      const jitter = Math.floor(Math.random() * JITTER)
      refreshTimer = setTimeout(() => scheduleRefresh(), backoffMs + jitter)
      return
    }
  }, delayMs)
}

function setAccessToken(token: string | null) {
  accessToken = token
  claims = token ? parseJwt(token) : null
  // Enforce admin-only
  if (claims && claims.role !== 'admin') {
    // clear immediately and trigger server-side logout
    accessToken = null
    claims = null
    clearTimer()
    notify()
    authClient.logout().catch(() => {})
    return
  }
  if (token) scheduleRefresh(); else clearTimer()
  notify()
}

async function proxy<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api/auth/${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers || {}) }
  })
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(text || String(res.status))
  }
  return res.json() as Promise<T>
}

export const authClient = {
  subscribe(cb: Subscriber) {
    subscribers.add(cb)
    return () => subscribers.delete(cb)
  },
  getAccessToken() { return accessToken },
  getClaims() { return claims },
  async login(identifier: string, password: string) {
    const r = await proxy<{ access_token: string }>('login', {
      method: 'POST',
      body: JSON.stringify({ identifier, password }),
    })
    setAccessToken(r.access_token)
    return { token: r.access_token, claims }
  },
  async refresh() {
    const r = await proxy<{ access_token: string }>('refresh', { method: 'POST' })
    setAccessToken(r.access_token)
    return { token: r.access_token, claims }
  },
  async logout() {
    try { await proxy('logout', { method: 'POST' }) } catch {}
    setAccessToken(null)
  },
  _set(token: string | null) { setAccessToken(token) }, // test hook
}

export default authClient
