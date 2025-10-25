'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import {
  listOrders,
  assignOrder,
  cancelOrder,
  deleteOrder,
  type Order
} from '@/lib/api';
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
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { AssignCourierDialog } from '@/components/modals/assign-courier-dialog';
import { NewOrderDialog } from '@/components/modals/new-order-dialog';
import { ViewOrderDialog } from '@/components/modals/view-order-dialog';
import { toast } from 'sonner';
import { IconDownload, IconPlus } from '@tabler/icons-react';
import { useAdminEvents } from '@/hooks/use-admin-events';

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
  const [showNewOrder, setShowNewOrder] = useState(false);
  const [viewOrderId, setViewOrderId] = useState<number | string | null>(null);
  const [deleteOrderId, setDeleteOrderId] = useState<number | string | null>(null);
  
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
  
  useAdminEvents((evt) => {
    if (evt.event === 'order.created') {
      refresh();
    }
  });
  
  useEffect(() => {
    refresh();
  }, [refresh]);
  
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
    setDeleteOrderId(id);
  }
  
  async function confirmDelete() {
    if (!deleteOrderId) return;
    
    try {
      await deleteOrder(deleteOrderId);
      toast.success('Order deleted');
      setDeleteOrderId(null);
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
          <Button onClick={() => setShowNewOrder(true)}>
            <IconPlus className="mr-2 h-4 w-4" />
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
              value={filter.status || 'all'}
              onValueChange={(value) =>
                setFilter((f) => ({ ...f, status: value === 'all' ? '' : value }))
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="All statuses" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                <SelectItem value="new">New</SelectItem>
                <SelectItem value="assigned">Assigned</SelectItem>
                <SelectItem value="accepted">Accepted</SelectItem>
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
              <IconDownload className="mr-2 h-4 w-4" />
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
                <TableHead>Boxes</TableHead>
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
                  <TableCell colSpan={6} className="text-center">
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
                    <TableCell>{order.boxes_count ?? 0}</TableCell>
                    <TableCell>{order.store_id ?? '-'}</TableCell>
                    <TableCell>{order.courier_id ?? '-'}</TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => setViewOrderId(order.id)}
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
        orderId={assignFor}
        onClose={() => setAssignFor(null)}
        onSelect={handleAssign}
      />
      
      <NewOrderDialog
        open={showNewOrder}
        onClose={() => setShowNewOrder(false)}
        onSuccess={refresh}
      />

      <ViewOrderDialog
        open={viewOrderId !== null}
        orderId={viewOrderId}
        onClose={() => setViewOrderId(null)}
        onSuccess={refresh}
      />
      
      <AlertDialog open={deleteOrderId !== null} onOpenChange={(open) => !open && setDeleteOrderId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Order</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to delete order #{deleteOrderId}? This action cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={confirmDelete} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
