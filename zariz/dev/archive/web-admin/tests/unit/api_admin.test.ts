import * as api from '../../libs/api'

describe('admin api client', () => {
  beforeEach(() => {
    // @ts-ignore
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ([]), text: async () => '' })
  })

  it('lists stores via admin route', async () => {
    await api.listStores()
    expect(global.fetch).toHaveBeenCalled()
    const url = (global.fetch as jest.Mock).mock.calls[0][0] as string
    expect(url).toContain('/admin/stores')
  })

  it('sets courier status', async () => {
    // @ts-ignore
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ ok: true }), text: async () => '' })
    await api.setCourierStatus(1, 'suspended')
    const body = (global.fetch as jest.Mock).mock.calls[0][1].body
    expect(body).toContain('suspended')
  })
})

