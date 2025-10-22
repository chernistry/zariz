import { useEffect } from 'react';

export function withAuth<P>(Comp: React.ComponentType<P>) {
  return (props: P) => {
    useEffect(() => {
      const token = typeof window !== 'undefined' ? localStorage.getItem('token') : null;
      if (!token) {
        location.href = '/login';
      }
    }, []);
    return <Comp {...props} />;
  };
}

