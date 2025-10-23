import type { NextApiRequest, NextApiResponse } from 'next'

const BASES = [
  process.env.BACKEND_API_BASE,
  process.env.NEXT_PUBLIC_API_BASE,
  'http://backend:8000/v1',
  'http://localhost:8000/v1',
].filter(Boolean) as string[]

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end()
  try {
    for (const base of BASES) {
      const r = await fetch(base + '/auth/refresh', { method: 'POST', headers: { 'Content-Type': 'application/json' } })
      if (r.ok) { const data = await r.json(); return res.status(200).json(data) }
    }
    return res.status(501).send('Refresh not available')
  } catch (e) {
    return res.status(501).send('Refresh not available')
  }
}
