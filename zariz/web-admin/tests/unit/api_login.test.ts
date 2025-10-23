import handler from '../../pages/api/auth/login'

function mockRes() {
  const headers: Record<string, string> = {}
  return {
    statusCode: 200,
    headers,
    setHeader: (k: string, v: string) => { headers[k] = v },
    status: function (code: number) { this.statusCode = code; return this },
    json: function (obj: any) { return { code: this.statusCode, body: obj, headers: this.headers } },
  } as any
}

describe('api/auth/login', () => {
  it('returns 400 for invalid payload', async () => {
    const req = { method: 'POST', body: { identifier: '', password: '' } } as any
    const res = mockRes()
    const r = await handler(req, res)
    expect(r.code).toBe(400)
    expect(r.body?.error).toBe('invalid_request')
  })
})

