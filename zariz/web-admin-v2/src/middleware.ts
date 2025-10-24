import { NextRequest, NextResponse } from 'next/server';

export default async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  
  // Allow public routes
  if (pathname.startsWith('/auth/login') || pathname.startsWith('/api/auth')) {
    return NextResponse.next();
  }
  
  // Protect dashboard routes
  if (pathname.startsWith('/dashboard')) {
    const refreshToken = req.cookies.get('refresh_token')?.value;
    
    if (!refreshToken) {
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
