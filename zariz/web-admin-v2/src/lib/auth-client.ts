/**
 * Lightweight in-memory auth client for Zariz admin
 * - Stores access token in memory only
 * - Schedules refresh when <2 minutes remain
 * - Proxies login/refresh/logout via Next.js API routes
 */

type Claims = {
  sub?: string;
  role?: string;
  exp?: number;
  name?: string;
  email?: string;
  store_ids?: number[];
  session_id?: string;
  [k: string]: unknown;
};

type Subscriber = (token: string | null, claims: Claims | null) => void;

let accessToken: string | null = null;
let claims: Claims | null = null;
let refreshTimer: ReturnType<typeof setTimeout> | null = null;
let refreshPromise: Promise<{ token: string; claims: Claims | null } | null> | null = null;

const REFRESH_ENABLED = process.env.NEXT_PUBLIC_AUTH_REFRESH === '1';
let backoffMs = 0;
const MAX_BACKOFF = 60_000;
const BASE_BACKOFF = 1_000;
const JITTER = 250;

function base64UrlToBase64(input: string) {
  input = input.replace(/-/g, '+').replace(/_/g, '/');
  const pad = input.length % 4;
  if (pad) input += '='.repeat(4 - pad);
  return input;
}

function parseJwt(token: string): Claims | null {
  try {
    const [, payload] = token.split('.');
    const json = atob(base64UrlToBase64(payload));
    return JSON.parse(json);
  } catch {
    return null;
  }
}

const subscribers = new Set<Subscriber>();

function notify() {
  subscribers.forEach((cb) => {
    try {
      cb(accessToken, claims);
    } catch {}
  });
}

function clearTimer() {
  if (refreshTimer) {
    clearTimeout(refreshTimer);
    refreshTimer = null;
  }
}

function scheduleRefresh() {
  if (!REFRESH_ENABLED) return;
  clearTimer();
  if (!claims?.exp) return;
  
  const nowSec = Math.floor(Date.now() / 1000);
  const lead = 120; // refresh 120s before expiry
  let delayMs = Math.max(0, (claims.exp - nowSec - lead) * 1000);
  
  if (delayMs === 0) delayMs = 250;
  
  refreshTimer = setTimeout(async () => {
    try {
      await authClient.refresh();
      backoffMs = 0;
    } catch {
      backoffMs = Math.min(MAX_BACKOFF, backoffMs === 0 ? BASE_BACKOFF : backoffMs * 2);
      const jitter = Math.floor(Math.random() * JITTER);
      refreshTimer = setTimeout(() => scheduleRefresh(), backoffMs + jitter);
    }
  }, delayMs);
}

function setAccessToken(token: string | null) {
  accessToken = token;
  claims = token ? parseJwt(token) : null;
  
  // Enforce admin-only
  if (claims && claims.role !== 'admin') {
    accessToken = null;
    claims = null;
    clearTimer();
    notify();
    authClient.logout().catch(() => {});
    return;
  }
  
  if (token) scheduleRefresh();
  else clearTimer();
  
  notify();
}

async function proxy<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api/auth/${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers || {}) }
  });
  
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(text || String(res.status));
  }
  
  return res.json() as Promise<T>;
}

export const authClient = {
  subscribe(cb: Subscriber) {
    subscribers.add(cb);
    return () => subscribers.delete(cb);
  },
  
  getAccessToken() {
    return accessToken;
  },
  
  getClaims() {
    return claims;
  },
  
  async login(identifier: string, password: string) {
    const r = await proxy<{ access_token: string }>('login', {
      method: 'POST',
      body: JSON.stringify({ identifier, password })
    });
    setAccessToken(r.access_token);
    return { token: r.access_token, claims };
  },
  
  async refresh() {
    if (refreshPromise) return refreshPromise;
    
    refreshPromise = (async () => {
      const r = await proxy<{ access_token: string }>('refresh', { method: 'POST' });
      setAccessToken(r.access_token);
      return { token: r.access_token, claims };
    })();
    
    try {
      return await refreshPromise;
    } finally {
      refreshPromise = null;
    }
  },
  
  async logout() {
    try {
      await proxy('logout', { method: 'POST' });
    } catch {}
    setAccessToken(null);
  },
  
  _set(token: string | null) {
    setAccessToken(token);
  }
};

export default authClient;
