'use client';

import { useEffect, useRef } from 'react';
import { eventBus } from '@/lib/event-bus';

export function useOrderEvents(handler: (event: any) => void) {
  const handlerRef = useRef(handler);

  useEffect(() => {
    handlerRef.current = handler;
  }, [handler]);

  useEffect(() => {
    return eventBus.subscribe((event) => handlerRef.current(event));
  }, []);
}
