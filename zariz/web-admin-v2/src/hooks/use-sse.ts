'use client';

import { useEffect, useRef } from 'react';

export function useSSE(url: string, onMessage: (data: any) => void) {
  const eventSourceRef = useRef<EventSource | null>(null);
  
  useEffect(() => {
    const eventSource = new EventSource(url);
    eventSourceRef.current = eventSource;
    
    eventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        onMessage(data);
      } catch (error) {
        console.error('SSE parse error:', error);
      }
    };
    
    eventSource.onerror = () => {
      eventSource.close();
      setTimeout(() => {
        if (eventSourceRef.current === eventSource) {
          const newEventSource = new EventSource(url);
          eventSourceRef.current = newEventSource;
        }
      }, 5000);
    };
    
    return () => {
      eventSource.close();
    };
  }, [url, onMessage]);
}
