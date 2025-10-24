import { useEffect, useRef, useState } from 'react';
import { authClient } from './authClient';

export function withAuth<P>(Comp: React.ComponentType<P>) {
  return (props: P) => {
    const [ready, setReady] = useState(false)
    const bootRef = useRef(false)

    useEffect(() => {
      let cancelled = false

      const ensureAuth = async () => {
        let token = authClient.getAccessToken()
        // Try to restore from localStorage (dev convenience only)
        if (!token && typeof window !== 'undefined') {
          try {
            const stored = localStorage.getItem('token')
            if (stored) {
              authClient._set(stored)
              token = stored
            }
          } catch {}
        }
        // Silent refresh on boot using httpOnly refresh cookie
        if (!token && !bootRef.current) {
          bootRef.current = true
          try {
            await authClient.refresh()
            token = authClient.getAccessToken()
          } catch {}
        }

        if (token) {
          if (!cancelled) setReady(true)
        } else if (typeof window !== 'undefined') {
          if (!cancelled) setReady(false)
          if (location.pathname !== '/login') location.replace('/login')
        }
      }

      const unsub = authClient.subscribe(() => ensureAuth())
      ensureAuth()
      return () => { cancelled = true; unsub && unsub() }
    }, [])

    if (!ready) return null
    return <Comp {...props} />
  }
}
