import { NextRequest, NextResponse } from 'next/server';

export default async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  
  if (pathname.startsWith('/auth/login') || pathname.startsWith('/api/auth')) {
    return NextResponse.next();
  }
  
  if (pathname.startsWith('/dashboard')) {
    const refreshToken = req.cookies.get('refresh_token')?.value;
    const isLocalhost = req.nextUrl.hostname === 'localhost' || req.nextUrl.hostname === '127.0.0.1';
    
    if (!refreshToken && !isLocalhost) {
      return NextResponse.redirect(new URL('/auth/login', req.url));
    }
  }
  
  return NextResponse.next();
}

export const config = {
  matcher: [
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    '/(api|trpc)(.*)'
  ]
};
