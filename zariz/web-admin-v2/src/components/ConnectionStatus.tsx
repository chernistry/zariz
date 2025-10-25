'use client';

import { useEffect, useRef } from 'react';
import { toast } from 'sonner';
import type { ConnectionStatus as Status } from '@/hooks/use-admin-events';

type ConnectionStatusProps = {
  status: Status;
};

export function ConnectionStatus({ status }: ConnectionStatusProps) {
  const prevStatusRef = useRef<Status>('disconnected');

  useEffect(() => {
    if (prevStatusRef.current === 'disconnected' && status === 'connecting') {
      toast.info('Reconnecting to server...', { id: 'reconnecting' });
    } else if (prevStatusRef.current === 'connecting' && status === 'connected') {
      toast.dismiss('reconnecting');
      toast.success('Connected to server');
    } else if (status === 'disconnected' && prevStatusRef.current === 'connected') {
      toast.error('Connection lost');
    }
    prevStatusRef.current = status;
  }, [status]);

  const colors = {
    connected: 'bg-green-500',
    connecting: 'bg-yellow-500',
    disconnected: 'bg-red-500'
  };

  const labels = {
    connected: 'Connected',
    connecting: 'Connecting...',
    disconnected: 'Disconnected'
  };

  return (
    <div className="flex items-center gap-2 text-sm text-muted-foreground">
      <div className={`w-2 h-2 rounded-full ${colors[status]}`} />
      <span>{labels[status]}</span>
    </div>
  );
}
