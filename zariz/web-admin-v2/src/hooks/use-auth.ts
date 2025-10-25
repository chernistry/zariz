'use client';

import { useEffect, useState } from 'react';
import { authClient } from '@/lib/auth-client';

export function useAuth() {
  const [token, setToken] = useState<string | null>(authClient.getAccessToken());
  const [claims, setClaims] = useState<any>(authClient.getClaims());
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    // Initialize auth client (will try to refresh if needed)
    authClient.init().finally(() => {
      setToken(authClient.getAccessToken());
      setClaims(authClient.getClaims());
      setLoading(false);
    });
    
    const unsubscribe = authClient.subscribe((newToken, newClaims) => {
      setToken(newToken);
      setClaims(newClaims);
    });
    
    return () => {
      unsubscribe();
    };
  }, []);
  
  return {
    token,
    claims,
    loading,
    isAuthenticated: !!token,
    user: claims ? {
      id: claims.sub,
      role: claims.role,
      name: claims.name || 'Admin User',
      email: claims.email || 'admin@zariz.local'
    } : null,
    login: authClient.login.bind(authClient),
    logout: authClient.logout.bind(authClient),
    refresh: authClient.refresh.bind(authClient)
  };
}
