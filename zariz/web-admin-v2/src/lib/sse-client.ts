import { authClient } from './auth-client';
import type { SSEEvent, ConnectionStatus } from '@/types/events';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000/v1';

type EventHandler = (event: SSEEvent) => void;

interface SSEDebugInfo {
  connects: number;
  subscribers: number;
  hasES: boolean;
  readyState: number | null;
  status: ConnectionStatus;
  connecting: boolean;
  hasReconnectTimer: boolean;
  lastErrorAt: number | null;
  connectMarker: number | null;
}

class SSEClient {
  private eventSource: EventSource | null = null;
  private handlers = new Set<EventHandler>();
  private status: ConnectionStatus = 'disconnected';
  private reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
  private reconnectDelay = 1000;
  private currentToken: string | null = null;
  private connecting = false;
  private connects = 0;
  private connectMarker: number | null = null;
  private lastErrorAt: number | null = null;

  constructor() {
    if (typeof window === 'undefined') return;

    const g = globalThis as any;
    if (g.__zarizSSE) {
      console.warn('[SSE] Duplicate SSEClient instantiation blocked');
      return;
    }
    g.__zarizSSE = {
      version: 1,
      active: false,
      connecting: false,
      refs: 0,
      connects: 0
    };

    authClient.subscribe((token) => {
      if (token !== this.currentToken) {
        console.log('[SSE] Token changed, reconnecting');
        this.currentToken = token;
        if (this.handlers.size > 0) {
          this.reconnect('token changed');
        }
      }
    });

    if (typeof window !== 'undefined') {
      (window as any).__zarizSSEDebug = () => this.getDebugInfo();
    }
  }

  subscribe(handler: EventHandler) {
    this.handlers.add(handler);
    const g = (globalThis as any).__zarizSSE;
    if (g) g.refs++;

    if (this.handlers.size === 1) {
      this.connect();
    }

    return () => {
      this.handlers.delete(handler);
      if (g) g.refs--;
      if (this.handlers.size === 0) {
        this.disconnect();
      }
    };
  }

  getStatus() {
    return this.status;
  }

  private setStatus(status: ConnectionStatus) {
    if (this.status !== status) {
      this.status = status;
      console.log(`[SSE] Status: ${status} (marker: ${this.connectMarker})`);
    }
  }

  private connect(force = false) {
    const g = (globalThis as any).__zarizSSE;

    if (!force && (this.connecting || (this.eventSource && this.eventSource.readyState !== EventSource.CLOSED))) {
      console.log('[SSE] connect() blocked: already connecting or connected', {
        connecting: this.connecting,
        readyState: this.eventSource?.readyState
      });
      return;
    }

    if (g && (g.active || g.connecting) && !force) {
      console.warn('[SSE] Global lock active, blocking connect()');
      return;
    }

    const token = authClient.getAccessToken();
    if (!token) {
      console.log('[SSE] No token, skipping connection');
      this.setStatus('disconnected');
      return;
    }

    if (this.eventSource) {
      try {
        this.eventSource.close();
      } catch {}
      this.eventSource = null;
    }

    this.currentToken = token;
    this.connecting = true;
    this.connects++;
    this.connectMarker = Math.random();
    if (g) {
      g.connecting = true;
      g.connects++;
    }

    this.setStatus('connecting');

    const url = `${API_BASE}/events/sse?token=${token}`;
    console.log(`[SSE] connect#${this.connects} (marker: ${this.connectMarker})`);

    const es = new EventSource(url);
    this.eventSource = es;

    es.onopen = () => {
      console.log(`[SSE] open (marker: ${this.connectMarker})`);
      this.connecting = false;
      if (g) {
        g.active = true;
        g.connecting = false;
      }
      this.setStatus('connected');
      this.reconnectDelay = 1000;
    };

    es.onmessage = (ev) => {
      try {
        const raw = JSON.parse(ev.data);
        const normalized: SSEEvent = raw && (raw.event || raw.type)
          ? { event: raw.event || raw.type, data: raw.data || raw }
          : { event: 'unknown', data: raw };

        this.handlers.forEach(h => {
          try {
            h(normalized);
          } catch (err) {
            console.error('[SSE] Handler error:', err);
          }
        });
      } catch (err) {
        console.error('[SSE] Parse error:', err);
      }
    };

    es.onerror = () => {
      this.lastErrorAt = Date.now();
      console.error(`[SSE] error (marker: ${this.connectMarker}, readyState: ${es.readyState})`);

      es.close();
      this.eventSource = null;
      this.connecting = false;
      if (g) {
        g.active = false;
        g.connecting = false;
      }
      this.setStatus('disconnected');

      if (!authClient.getAccessToken()) {
        console.log('[SSE] No token, stopping reconnection');
        return;
      }

      if (this.handlers.size === 0) {
        console.log('[SSE] No subscribers, stopping reconnection');
        return;
      }

      if (this.reconnectTimeout) {
        console.log('[SSE] reconnect timer already scheduled, skipping');
        return;
      }

      const jitter = Math.random() * 1000;
      const delay = Math.min(this.reconnectDelay, 30000) + jitter;
      console.log(`[SSE] Reconnecting in ${Math.round(delay)}ms`);

      this.reconnectTimeout = setTimeout(() => {
        this.reconnectTimeout = null;
        this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30000);
        this.connect();
      }, delay);
    };
  }

  private disconnect() {
    console.log('[SSE] disconnect()');

    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }

    if (this.eventSource) {
      try {
        this.eventSource.close();
      } catch {}
      this.eventSource = null;
    }

    this.connecting = false;
    const g = (globalThis as any).__zarizSSE;
    if (g) {
      g.active = false;
      g.connecting = false;
    }

    this.setStatus('disconnected');
  }

  private reconnect(reason: string) {
    console.log(`[SSE] reconnect(${reason})`);
    this.disconnect();
    if (this.handlers.size > 0) {
      this.connect();
    }
  }

  private getDebugInfo(): SSEDebugInfo {
    return {
      connects: this.connects,
      subscribers: this.handlers.size,
      hasES: !!this.eventSource,
      readyState: this.eventSource?.readyState ?? null,
      status: this.status,
      connecting: this.connecting,
      hasReconnectTimer: !!this.reconnectTimeout,
      lastErrorAt: this.lastErrorAt,
      connectMarker: this.connectMarker
    };
  }
}

const g = globalThis as any;
if (!g.__zarizSSEClient) {
  g.__zarizSSEClient = new SSEClient();
}

export const sseClient: SSEClient = g.__zarizSSEClient;
