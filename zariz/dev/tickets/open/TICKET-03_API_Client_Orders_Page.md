# TICKET-03: API Client and Orders Page Migration

**READ FIRST:** `/Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md`

## Objective
Implement the API client with automatic authentication and migrate the Orders page with full CRUD functionality, real-time updates via SSE, and CSV export.

## Context
The current Orders page uses Material UI components and connects to the backend via a custom API client. We need to:
1. Create a new API client that integrates with the auth system
2. Migrate the Orders page to use shadcn/ui components
3. Implement SSE for real-time updates
4. Add filtering, CSV export, and order management actions

## Reference Implementation
- Current: `/Users/sasha/IdeaProjects/ios/zariz/web-admin/pages/orders.tsx`
- Current API: `/Users/sasha/IdeaProjects/ios/zariz/web-admin/libs/api.ts`
- Octup reference: `/Users/sasha/IdeaProjects/octup/root/dashboard/src/lib/api.ts`

## Acceptance Criteria
- [ ] API client with auto-retry and auth integration
- [ ] Orders page displays list of orders
- [ ] Filters work (status, store, courier, date range)
- [ ] Real-time updates via SSE
- [ ] CSV export functionality
- [ ] Order actions: View, Assign, Cancel, Delete
- [ ] Assign courier dialog functional
- [ ] Error handling and loading states
- [ ] Responsive design

## Implementation Steps

### 1. Create API Client

**File: `src/lib/api.ts`**
```typescript
import { authClient } from './auth-client';

export const API_BASE = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000/v1';

export async function api(path: string, opts: RequestInit = {}) {
  const run = async (): Promise<Response> => {
    const token = authClient.getAccessToken() || undefined;
    const headers = {
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    } as Record<string, string>;
    
    return fetch(`${API_BASE}/${path}`, { ...opts, headers });
  };
  
  // Initial attempt
  let res = await run();
  
  // If unauthorized, try to refresh and retry once
  if (res.status === 401) {
    try {
      await authClient.refresh();
      res = await run();
    } catch {
      // Refresh failed, will throw below
    }
  }
  
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(text || String(res.status));
  }
  
  return res.json();
}

// Types
export type Order = {
  id: string | number;
  status: string;
  store_id?: number;
  courier_id?: number | null;
  created_at?: string;
  pickup_address?: string;
  delivery_address?: string;
  recipient_first_name?: string;
  recipient_last_name?: string;
  phone?: string;
  boxes_count?: number;
};

export type CourierInfo = {
  id: number;
  name: string;
  capacity_boxes: number;
  load_boxes: number;
  available_boxes: number;
};

export type Store = {
  id: number;
  name: string;
  status?: 'active' | 'suspended' | 'offboarded';
  pickup_address?: string;
  box_limit?: number;
  hours_text?: string;
};

export type CourierAdmin = {
  id: number;
  name: string;
  email?: string | null;
  phone?: string | null;
  capacity_boxes?: number;
  status?: 'active' | 'suspended' | 'offboarded';
};

// Order APIs
export async function listOrders(params?: Record<string, string>): Promise<Order[]> {
  const query = params ? `?${new URLSearchParams(params)}` : '';
  return api(`orders${query}`);
}

export async function getOrder(id: string | number): Promise<Order> {
  return api(`orders/${id}`);
}

export async function assignOrder(id: string | number, courierId: number): Promise<{ ok: boolean }> {
  return api(`orders/${id}/assign`, {
    method: 'POST',
    body: JSON.stringify({ courier_id: courierId })
  });
}

export async function cancelOrder(id: string | number, reason: string): Promise<{ ok: boolean }> {
  return api(`orders/${id}/cancel`, {
    method: 'POST',
    body: JSON.stringify({ reason })
  });
}

export async function deleteOrder(id: string | number): Promise<{ ok: boolean }> {
  return api(`orders/${id}`, { method: 'DELETE' });
}

// Courier APIs
export async function getCouriers(availableOnly = true): Promise<CourierInfo[]> {
  return api(`couriers?available_only=${availableOnly ? 1 : 0}`);
}

export async function listCouriersAdmin(): Promise<CourierAdmin[]> {
  return api('admin/couriers');
}

// Store APIs
export async function listStores(): Promise<Store[]> {
  return api('admin/stores');
}
```

### 2. Create SSE Hook

**File: `src/hooks/use-sse.ts`**
```typescript
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
      // Reconnect after 5 seconds
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
```

### 3. Create Assign Courier Dialog

**File: `src/components/modals/assign-courier-dialog.tsx`**
```typescript
'use client';

import { useEffect, useState } from 'react';
import { getCouriers, type CourierInfo } from '@/lib/api';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Loader2 } from 'lucide-react';

interface AssignCourierDialogProps {
  open: boolean;
  onClose: () => void;
  onSelect: (courierId: number) => void;
}

export function AssignCourierDialog({
  open,
  onClose,
  onSelect
}: AssignCourierDialogProps) {
  const [couriers, setCouriers] = useState<CourierInfo[]>([]);
  const [loading, setLoading] = useState(false);
  
  useEffect(() => {
    if (open) {
      setLoading(true);
      getCouriers(true)
        .then(setCouriers)
        .catch(() => setCouriers([]))
        .finally(() => setLoading(false));
    }
  }, [open]);
  
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Assign Courier</DialogTitle>
          <DialogDescription>
            Select an available courier to assign this order
          </DialogDescription>
        </DialogHeader>
        
        {loading ? (
          <div className="flex items-center justify-center py-8">
            <Loader2 className="h-6 w-6 animate-spin" />
          </div>
        ) : (
          <ScrollArea className="max-h-[400px]">
            <div className="space-y-2">
              {couriers.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">
                  No available couriers
                </p>
              ) : (
                couriers.map((courier) => (
                  <Button
                    key={courier.id}
                    variant="outline"
                    className="w-full justify-between"
                    onClick={() => {
                      onSelect(courier.id);
                      onClose();
                    }}
                  >
                    <span>{courier.name}</span>
                    <span className="text-xs text-muted-foreground">
                      {courier.available_boxes}/{courier.capacity_boxes} boxes
                    </span>
                  </Button>
                ))
              )}
            </div>
          </ScrollArea>
        )}
      </DialogContent>
    </Dialog>
  );
}
```

### 4. Create Orders Page

**File: `src/app/dashboard/orders/page.tsx`**
```typescript
'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import {
  listOrders,
  assignOrder,
  cancelOrder,
  deleteOrder,
  type Order,
  API_BASE
} from '@/lib/api';
import { useSSE } from '@/hooks/use-sse';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from '@/components/ui/select';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow
} from '@/components/ui/table';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { AssignCourierDialog } from '@/components/modals/assign-courier-dialog';
import { toast } from 'sonner';
import { Download, Plus } from 'lucide-react';

type Filter = {
  status: string;
  store: string;
  courier: string;
  from: string;
  to: string;
};

export default function OrdersPage() {
  const router = useRouter();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<Filter>({
    status: '',
    store: '',
    courier: '',
    from: '',
    to: ''
  });
  const [assignFor, setAssignFor] = useState<number | string | null>(null);
  
  const refresh = useCallback(async () => {
    try {
      const params: Record<string, string> = {};
      Object.entries(filter).forEach(([k, v]) => {
        if (v) params[k] = v;
      });
      const data = await listOrders(params);
      setOrders(data);
    } catch (error) {
      toast.error('Failed to load orders');
    } finally {
      setLoading(false);
    }
  }, [filter]);
  
  useEffect(() => {
    refresh();
  }, [refresh]);
  
  // Real-time updates via SSE
  useSSE(`${API_BASE}/events/sse`, (msg: any) => {
    if (typeof msg?.type === 'string' && msg.type.startsWith('order.')) {
      refresh();
    }
  });
  
  function exportCSV() {
    const header = ['id', 'status', 'store_id', 'courier_id', 'created_at'];
    const rows = orders.map((o) => [
      o.id,
      o.status,
      o.store_id ?? '',
      o.courier_id ?? '',
      o.created_at ?? ''
    ]);
    const csv = [header, ...rows]
      .map((r) =>
        r
          .map(String)
          .map((s) => `"${s.replaceAll('"', '""')}"`)
          .join(',')
      )
      .join('\n');
    
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'orders.csv';
    a.click();
    URL.revokeObjectURL(url);
  }
  
  async function handleAssign(courierId: number) {
    if (!assignFor) return;
    
    try {
      await assignOrder(assignFor, courierId);
      toast.success('Order assigned successfully');
      setAssignFor(null);
      await refresh();
    } catch (error) {
      toast.error('Failed to assign order');
    }
  }
  
  async function handleCancel(id: number | string) {
    const reason = prompt('Cancel reason?') || '';
    
    try {
      await cancelOrder(id, reason);
      toast.success('Order canceled');
      await refresh();
    } catch (error) {
      toast.error('Failed to cancel order');
    }
  }
  
  async function handleDelete(id: number | string) {
    if (!confirm(`Delete order #${id}? This cannot be undone.`)) return;
    
    try {
      await deleteOrder(id);
      toast.success('Order deleted');
      await refresh();
    } catch (error) {
      toast.error('Failed to delete order');
    }
  }
  
  return (
    <div className="flex-1 space-y-4 p-4 md:p-8 pt-6">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold tracking-tight">Orders</h2>
        <div className="flex items-center gap-2">
          <Button onClick={() => router.push('/dashboard/orders/new')}>
            <Plus className="mr-2 h-4 w-4" />
            New Order
          </Button>
        </div>
      </div>
      
      <Card>
        <CardHeader>
          <CardTitle>Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
            <Select
              value={filter.status}
              onValueChange={(value) =>
                setFilter((f) => ({ ...f, status: value }))
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="All statuses" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="">All</SelectItem>
                <SelectItem value="new">New</SelectItem>
                <SelectItem value="assigned">Assigned</SelectItem>
                <SelectItem value="claimed">Claimed</SelectItem>
                <SelectItem value="picked_up">Picked up</SelectItem>
                <SelectItem value="delivered">Delivered</SelectItem>
                <SelectItem value="canceled">Canceled</SelectItem>
              </SelectContent>
            </Select>
            
            <Input
              placeholder="Store ID"
              value={filter.store}
              onChange={(e) =>
                setFilter((f) => ({ ...f, store: e.target.value }))
              }
            />
            
            <Input
              placeholder="Courier ID"
              value={filter.courier}
              onChange={(e) =>
                setFilter((f) => ({ ...f, courier: e.target.value }))
              }
            />
            
            <Input
              type="date"
              placeholder="From"
              value={filter.from}
              onChange={(e) =>
                setFilter((f) => ({ ...f, from: e.target.value }))
              }
            />
            
            <Input
              type="date"
              placeholder="To"
              value={filter.to}
              onChange={(e) =>
                setFilter((f) => ({ ...f, to: e.target.value }))
              }
            />
          </div>
          
          <div className="mt-4">
            <Button variant="outline" size="sm" onClick={exportCSV}>
              <Download className="mr-2 h-4 w-4" />
              Export CSV
            </Button>
          </div>
        </CardContent>
      </Card>
      
      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>ID</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Store</TableHead>
                <TableHead>Courier</TableHead>
                <TableHead>Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-center">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : orders.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-center">
                    No orders found
                  </TableCell>
                </TableRow>
              ) : (
                orders.map((order) => (
                  <TableRow key={String(order.id)}>
                    <TableCell>#{String(order.id)}</TableCell>
                    <TableCell>
                      {order.status === 'assigned'
                        ? 'Awaiting acceptance'
                        : order.status}
                    </TableCell>
                    <TableCell>{order.store_id ?? '-'}</TableCell>
                    <TableCell>{order.courier_id ?? '-'}</TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() =>
                            router.push(`/dashboard/orders/${order.id}`)
                          }
                        >
                          View
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => setAssignFor(order.id)}
                        >
                          Assign
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => handleCancel(order.id)}
                        >
                          Cancel
                        </Button>
                        <Button
                          size="sm"
                          variant="destructive"
                          onClick={() => handleDelete(order.id)}
                        >
                          Delete
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
      
      <AssignCourierDialog
        open={assignFor !== null}
        onClose={() => setAssignFor(null)}
        onSelect={handleAssign}
      />
    </div>
  );
}
```

### 5. Update Sidebar Navigation

**File: `src/constants/data.ts`**
```typescript
import { NavItem } from '@/types';

export const navItems: NavItem[] = [
  {
    title: 'Dashboard',
    href: '/dashboard',
    icon: 'dashboard',
    label: 'Dashboard'
  },
  {
    title: 'Orders',
    href: '/dashboard/orders',
    icon: 'package',
    label: 'orders'
  },
  {
    title: 'Stores',
    href: '/dashboard/stores',
    icon: 'store',
    label: 'stores'
  },
  {
    title: 'Couriers',
    href: '/dashboard/couriers',
    icon: 'user',
    label: 'couriers'
  }
];
```

## Testing Checklist

- [ ] Orders page loads and displays orders
- [ ] Filters work correctly
- [ ] CSV export downloads file
- [ ] View button navigates to order detail
- [ ] Assign dialog opens and shows couriers
- [ ] Assigning courier works
- [ ] Cancel order works with reason prompt
- [ ] Delete order works with confirmation
- [ ] Real-time updates work (test with backend SSE)
- [ ] Loading states display correctly
- [ ] Error toasts show on failures
- [ ] Responsive design works on mobile

## Notes

- SSE reconnects automatically on disconnect
- All mutations show toast notifications
- Filters trigger automatic refresh
- CSV export includes all filtered orders
- Real-time updates refresh entire list (simple approach)

## Next Ticket
TICKET-04 will migrate Stores and Couriers pages.
