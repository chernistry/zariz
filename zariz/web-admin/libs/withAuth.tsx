import { useEffect } from 'react';
import { authClient } from './authClient';

export function withAuth<P>(Comp: React.ComponentType<P>) {
  return (props: P) => {
    useEffect(() => {
      const check = () => {
        const token = authClient.getAccessToken()
        if (!token && typeof window !== 'undefined') location.href = '/login'
      }
      const unsub = authClient.subscribe(() => check())
      check()
      return () => { unsub && unsub() }
    }, []);
    return <Comp {...props} />;
  };
}
