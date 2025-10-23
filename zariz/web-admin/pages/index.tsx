import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { authClient } from '../libs/authClient';

export default function IndexRedirect() {
  const router = useRouter();
  useEffect(() => {
    const go = () => router.replace(authClient.getAccessToken() ? '/orders' : '/login')
    const unsub = authClient.subscribe(() => go())
    go()
    return () => { unsub && unsub() }
  }, [router]);
  return null;
}
