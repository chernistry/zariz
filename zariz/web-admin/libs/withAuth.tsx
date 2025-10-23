import { useEffect, useState } from 'react';
import { authClient } from './authClient';

export function withAuth<P>(Comp: React.ComponentType<P>) {
  return (props: P) => {
    const [ready, setReady] = useState(false)
    useEffect(() => {
      let cancelled = false
      const check = () => {
        let token = authClient.getAccessToken()
        if (!token && typeof window !== 'undefined') {
          try {
            const stored = localStorage.getItem('token')
            if (stored) {
              authClient._set(stored)
              token = stored
            }
          } catch {}
        }
        if (token) {
          if (!cancelled) setReady(true)
        } else if (typeof window !== 'undefined') {
          if (!cancelled) setReady(false)
          if (location.pathname !== '/login') location.replace('/login')
        }
      }
      const unsub = authClient.subscribe(() => check())
      check()
      return () => { cancelled = true; unsub && unsub() }
    }, []);
    if (!ready) return null
    return <Comp {...props} />;
  };
}
