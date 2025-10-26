'use client';

import { useEffect, useState, useRef } from 'react';
import { sseClient } from '@/lib/sse-client';
import type { SSEEvent, ConnectionStatus } from '@/types/events';

export function useSSEEvents(handler?: (event: SSEEvent) => void) {
  const [status, setStatus] = useState<ConnectionStatus>(() => sseClient.getStatus());
  const handlerRef = useRef(handler);

  useEffect(() => {
    handlerRef.current = handler;
  }, [handler]);

  useEffect(() => {
    if (!handlerRef.current) return;

    const unsubscribe = sseClient.subscribe((event) => {
      handlerRef.current?.(event);
    });

    const interval = setInterval(() => {
      setStatus(sseClient.getStatus());
    }, 1000);

    return () => {
      unsubscribe();
      clearInterval(interval);
    };
  }, []);

  return { status };
}
