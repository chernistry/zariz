import { authClient } from '../../libs/authClient'

function b64url(s: string) {
  // @ts-ignore
  const enc = (typeof btoa !== 'undefined' ? btoa(s) : Buffer.from(s, 'binary').toString('base64'))
  return enc.replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_')
}

function makeJwt(payload: Record<string, any>) {
  const header = b64url(JSON.stringify({ alg: 'none', typ: 'JWT' }))
  const body = b64url(JSON.stringify(payload))
  return `${header}.${body}.`
}

describe('authClient', () => {
  beforeEach(() => {
    // @ts-ignore
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ ok: true }) })
    authClient._set(null)
  })

  it('stores admin token in memory', () => {
    const exp = Math.floor(Date.now()/1000) + 3600
    const token = makeJwt({ role: 'admin', exp })
    const seen: (string|null)[] = []
    const unsub = authClient.subscribe((t) => seen.push(t))
    authClient._set(token)
    expect(authClient.getAccessToken()).toBe(token)
    expect(seen[seen.length-1]).toBe(token)
    unsub()
  })

  it('forces logout for non-admin tokens', async () => {
    const exp = Math.floor(Date.now()/1000) + 3600
    const token = makeJwt({ role: 'courier', exp })
    authClient._set(token)
    // logout is async; wait microtask
    await Promise.resolve()
    expect(authClient.getAccessToken()).toBe(null)
  })
})
