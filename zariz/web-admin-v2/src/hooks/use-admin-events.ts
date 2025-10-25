/**
 * @deprecated Use useSSEEvents from '@/hooks/use-sse-events' instead.
 * This hook creates its own EventSource connection which can lead to multiple connections.
 * The new useSSEEvents uses a singleton SSE client to ensure only one connection per tab.
 */

'use client';

import { useEffect, useRef, useState } from 'react';
import { useAuth } from './use-auth';
import { authClient } from '@/lib/auth-client';
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
  const onEventRef = useRef(onEvent);

  useEffect(() => {
    onEventRef.current = onEvent;
  }, [onEvent]);

  useEffect(() => {
    if (loading || !isAuthenticated || !token) {
      console.log('[SSE] Not ready:', { loading, isAuthenticated, hasToken: !!token });
      setStatus('disconnected');
      return;
    }

    const connect = () => {
      const currentToken = authClient.getAccessToken();
      if (!currentToken) {
        console.log('[SSE] Halting connection: No token available.');
        setStatus('disconnected');
        return;
      }

      if (eventSourceRef.current) {
        eventSourceRef.current.close();
      }

      setStatus('connecting');
      const url = `${API_BASE}/events/sse?token=${currentToken}`;
      console.log('[SSE] Connecting to:', url.replace(currentToken, 'TOKEN'));
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
          const raw = JSON.parse(event.data);
          const normalized = raw && (raw.event || raw.type)
            ? { event: raw.event || raw.type, data: raw.data || raw }
            : { event: 'unknown', data: raw };
          console.log('[SSE] Normalized event:', normalized);
          if (onEventRef.current) onEventRef.current(normalized as any);
        } catch (err) {
          console.error('[SSE] Parse error:', err);
        }
      };

      eventSource.onerror = (err) => {
        console.error('[SSE] Error:', err);
        eventSource.close();
        setStatus('disconnected');

        const currentToken = authClient.getAccessToken();
        if (!currentToken) {
          console.log('[SSE] Token no longer available, stopping reconnection.');
          if (reconnectTimeoutRef.current) clearTimeout(reconnectTimeoutRef.current);
          return;
        }

        const baseDelay = Math.min(reconnectDelayRef.current, 30000);
        const jitter = Math.random() * 1000;
        const delay = baseDelay + jitter;
        console.log(`[SSE] Reconnecting in ${Math.round(delay)}ms`);
        reconnectTimeoutRef.current = setTimeout(() => {
          reconnectDelayRef.current = Math.min(baseDelay * 2, 30000);
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
  }, [token, isAuthenticated, loading]);

  return { status };
}
