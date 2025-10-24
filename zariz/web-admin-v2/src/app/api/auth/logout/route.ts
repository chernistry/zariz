import { NextRequest, NextResponse } from 'next/server';

// Use internal Docker network for server-side requests
const API_BASE = process.env.INTERNAL_API_BASE || process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000/v1';

export async function POST(req: NextRequest) {
  try {
    const refreshToken = req.cookies.get('refresh_token')?.value;
    
    if (refreshToken) {
      await fetch(`${API_BASE}/auth/logout`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ refresh_token: refreshToken })
      }).catch(() => {});
    }
    
    const response = NextResponse.json({ ok: true });
    response.cookies.delete('refresh_token');
    
    return response;
  } catch (error) {
    const response = NextResponse.json({ ok: true });
    response.cookies.delete('refresh_token');
    return response;
  }
}
