import { authClient } from './auth-client';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000/v1';

export type SSEEvent = {
  event: string;
  data: any;
};

export type ConnectionStatus = 'connected' | 'connecting' | 'disconnected';
type EventHandler = (event: SSEEvent) => void;

class SSEClient {
  private eventSource: EventSource | null = null;
  private handlers = new Set<EventHandler>();
  private status: ConnectionStatus = 'disconnected';
  private reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
  private reconnectDelay = 1000;
  private currentToken: string | null = null;

  constructor() {
    if (typeof window === 'undefined') return;
    
    authClient.subscribe((token) => {
      if (token !== this.currentToken) {
        console.log('[SSE] Token changed, reconnecting');
        this.currentToken = token;
        if (this.handlers.size > 0) {
          this.reconnect();
        }
      }
    });
  }

  subscribe(handler: EventHandler) {
    this.handlers.add(handler);
    if (this.handlers.size === 1) {
      this.connect();
    }
    return () => {
      this.handlers.delete(handler);
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
      console.log('[SSE] Status:', status);
    }
  }

  private connect() {
    if (this.eventSource) {
      console.log('[SSE] Already connected/connecting');
      return;
    }

    const token = authClient.getAccessToken();
    if (!token) {
      console.log('[SSE] No token, skipping connection');
      this.setStatus('disconnected');
      return;
    }

    this.currentToken = token;
    this.setStatus('connecting');
    
    const url = `${API_BASE}/events/sse?token=${token}`;
    console.log('[SSE] Connecting...');
    
    const es = new EventSource(url);
    this.eventSource = es;

    es.onopen = () => {
      console.log('[SSE] Connected');
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
      console.error('[SSE] Connection error');
      es.close();
      this.eventSource = null;
      this.setStatus('disconnected');

      if (!authClient.getAccessToken()) {
        console.log('[SSE] No token, stopping reconnection');
        return;
      }

      if (this.handlers.size === 0) {
        console.log('[SSE] No subscribers, stopping reconnection');
        return;
      }

      const jitter = Math.random() * 1000;
      const delay = Math.min(this.reconnectDelay, 30000) + jitter;
      console.log(`[SSE] Reconnecting in ${Math.round(delay)}ms`);
      
      this.reconnectTimeout = setTimeout(() => {
        this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30000);
        this.connect();
      }, delay);
    };
  }

  private disconnect() {
    console.log('[SSE] Disconnecting');
    
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }

    if (this.eventSource) {
      this.eventSource.close();
      this.eventSource = null;
    }

    this.setStatus('disconnected');
  }

  private reconnect() {
    this.disconnect();
    if (this.handlers.size > 0) {
      this.connect();
    }
  }
}

const g = globalThis as any;
if (!g.__zarizSSEClient) {
  g.__zarizSSEClient = new SSEClient();
}

export const sseClient: SSEClient = g.__zarizSSEClient;
