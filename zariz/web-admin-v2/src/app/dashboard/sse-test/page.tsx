'use client';

import { useState } from 'react';
import { useSSEEvents } from '@/hooks/use-sse-events';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';

export default function SSETestPage() {
  const [events, setEvents] = useState<Array<{ time: string; event: string; data: any }>>([]);
  const [subscriber1Active, setSubscriber1Active] = useState(true);
  const [subscriber2Active, setSubscriber2Active] = useState(false);
  const [subscriber3Active, setSubscriber3Active] = useState(false);

  const { status: status1 } = useSSEEvents(
    subscriber1Active
      ? (event) => {
          setEvents((prev) => [
            { time: new Date().toISOString(), event: event.event, data: event.data },
            ...prev.slice(0, 49)
          ]);
        }
      : undefined
  );

  const { status: status2 } = useSSEEvents(
    subscriber2Active
      ? (event) => {
          console.log('[Subscriber 2]', event);
        }
      : undefined
  );

  const { status: status3 } = useSSEEvents(
    subscriber3Active
      ? (event) => {
          console.log('[Subscriber 3]', event);
        }
      : undefined
  );

  return (
    <div className="flex-1 space-y-4 p-4 md:p-8 pt-6">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold tracking-tight">SSE Connection Test</h2>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Connection Status</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-4">
            <span className="font-medium">Subscriber 1:</span>
            <Badge variant={status1 === 'connected' ? 'default' : 'secondary'}>
              {status1}
            </Badge>
            <Button
              size="sm"
              variant={subscriber1Active ? 'destructive' : 'default'}
              onClick={() => setSubscriber1Active(!subscriber1Active)}
            >
              {subscriber1Active ? 'Deactivate' : 'Activate'}
            </Button>
          </div>

          <div className="flex items-center gap-4">
            <span className="font-medium">Subscriber 2:</span>
            <Badge variant={status2 === 'connected' ? 'default' : 'secondary'}>
              {status2}
            </Badge>
            <Button
              size="sm"
              variant={subscriber2Active ? 'destructive' : 'default'}
              onClick={() => setSubscriber2Active(!subscriber2Active)}
            >
              {subscriber2Active ? 'Deactivate' : 'Activate'}
            </Button>
          </div>

          <div className="flex items-center gap-4">
            <span className="font-medium">Subscriber 3:</span>
            <Badge variant={status3 === 'connected' ? 'default' : 'secondary'}>
              {status3}
            </Badge>
            <Button
              size="sm"
              variant={subscriber3Active ? 'destructive' : 'default'}
              onClick={() => setSubscriber3Active(!subscriber3Active)}
            >
              {subscriber3Active ? 'Deactivate' : 'Activate'}
            </Button>
          </div>

          <div className="pt-4 border-t">
            <p className="text-sm text-muted-foreground">
              Open DevTools → Network tab and filter for &quot;sse&quot;. You should see exactly ONE
              connection regardless of how many subscribers are active.
            </p>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Recent Events ({events.length})</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-2 max-h-96 overflow-y-auto">
            {events.length === 0 ? (
              <p className="text-sm text-muted-foreground">No events received yet</p>
            ) : (
              events.map((evt, idx) => (
                <div key={idx} className="p-2 border rounded text-sm">
                  <div className="flex items-center gap-2 mb-1">
                    <Badge variant="outline">{evt.event}</Badge>
                    <span className="text-xs text-muted-foreground">
                      {new Date(evt.time).toLocaleTimeString()}
                    </span>
                  </div>
                  <pre className="text-xs overflow-x-auto">
                    {JSON.stringify(evt.data, null, 2)}
                  </pre>
                </div>
              ))
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
