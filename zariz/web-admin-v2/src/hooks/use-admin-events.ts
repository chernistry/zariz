'use client';

import { useEffect, useRef, useState } from 'react';
import { useAuth } from './use-auth';
import { API_BASE } from '@/lib/api';

export type OrderEvent = {
  event: string;
  data: {
    order_id: number;
    store_id: number;
    pickup_address: string;
    delivery_address: string;
    boxes_count: number;
    price_total: number;
    created_at: string;
  };
};

export type ConnectionStatus = 'connected' | 'connecting' | 'disconnected';

export function useAdminEvents(onEvent?: (event: OrderEvent) => void) {
  const [status, setStatus] = useState<ConnectionStatus>('disconnected');
  const { token, isAuthenticated, loading } = useAuth();
  const eventSourceRef = useRef<EventSource | null>(null);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout | undefined>(undefined);
  const reconnectDelayRef = useRef(1000);

  useEffect(() => {
    if (loading || !isAuthenticated || !token) {
      console.log('[SSE] Not ready:', { loading, isAuthenticated, hasToken: !!token });
      setStatus('disconnected');
      return;
    }

    const connect = () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
      }

      setStatus('connecting');
      const url = `${API_BASE}/events/sse?token=${token}`;
      console.log('[SSE] Connecting to:', url.replace(token, 'TOKEN'));
      const eventSource = new EventSource(url);
      eventSourceRef.current = eventSource;

      eventSource.onopen = () => {
        console.log('[SSE] Connected');
        setStatus('connected');
        reconnectDelayRef.current = 1000;
      };

      eventSource.onmessage = (event) => {
        console.log('[SSE] Message received:', event.data);
        try {
          const parsed = JSON.parse(event.data);
          console.log('[SSE] Parsed event:', parsed);
          if (parsed.event === 'order.created' && onEvent) {
            console.log('[SSE] Calling onEvent handler');
            onEvent(parsed);
          }
        } catch (err) {
          console.error('[SSE] Parse error:', err);
        }
      };

      eventSource.onerror = (err) => {
        console.error('[SSE] Error:', err);
        eventSource.close();
        setStatus('disconnected');

        const delay = Math.min(reconnectDelayRef.current, 30000);
        console.log(`[SSE] Reconnecting in ${delay}ms`);
        reconnectTimeoutRef.current = setTimeout(() => {
          reconnectDelayRef.current = Math.min(delay * 2, 30000);
          connect();
        }, delay);
      };
    };

    connect();

    return () => {
      console.log('[SSE] Cleanup');
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
      }
    };
  }, [token, isAuthenticated, loading, onEvent]);

  return { status };
}
