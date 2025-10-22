import { useEffect } from 'react';
import { useRouter } from 'next/router';

export default function IndexRedirect() {
  const router = useRouter();
  useEffect(() => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('token') : null;
    router.replace(token ? '/orders' : '/login');
  }, [router]);
  return null;
}
