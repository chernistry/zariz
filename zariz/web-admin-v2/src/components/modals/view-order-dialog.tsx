'use client';

import { useState, useEffect } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { getOrder, type Order, api } from '@/lib/api';
import { toast } from 'sonner';

type ViewOrderDialogProps = {
  open: boolean;
  orderId: string | number | null;
  onClose: () => void;
  onSuccess: () => void;
};

export function ViewOrderDialog({ open, orderId, onClose, onSuccess }: ViewOrderDialogProps) {
  const [order, setOrder] = useState<Order | null>(null);
  const [loading, setLoading] = useState(false);
  const [editing, setEditing] = useState(false);
  const [formData, setFormData] = useState<Partial<Order>>({});

  useEffect(() => {
    if (open && orderId) {
      loadOrder();
    }
  }, [open, orderId]);

  async function loadOrder() {
    if (!orderId) return;
    setLoading(true);
    try {
      const data = await getOrder(orderId);
      setOrder(data);
      setFormData(data);
    } catch (error) {
      toast.error('Failed to load order');
    } finally {
      setLoading(false);
    }
  }

  async function handleSave() {
    if (!orderId) return;
    setLoading(true);
    try {
      await api(`orders/${orderId}`, {
        method: 'PATCH',
        body: JSON.stringify(formData)
      });
      toast.success('Order updated');
      onSuccess();
      onClose();
    } catch (error) {
      toast.error('Failed to update order');
    } finally {
      setLoading(false);
    }
  }

  async function handleDelete() {
    if (!orderId || !confirm(`Delete order #${orderId}?`)) return;
    setLoading(true);
    try {
      await api(`orders/${orderId}`, { method: 'DELETE' });
      toast.success('Order deleted');
      onSuccess();
      onClose();
    } catch (error) {
      toast.error('Failed to delete order');
    } finally {
      setLoading(false);
    }
  }

  if (!order) {
    return (
      <Dialog open={open} onOpenChange={onClose}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Loading...</DialogTitle>
          </DialogHeader>
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Order #{order.id}</DialogTitle>
        </DialogHeader>

        <div className="grid gap-4 py-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label>Status</Label>
              {editing ? (
                <Select
                  value={formData.status}
                  onValueChange={(value) => setFormData({ ...formData, status: value })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="new">New</SelectItem>
                    <SelectItem value="assigned">Assigned</SelectItem>
                    <SelectItem value="claimed">Claimed</SelectItem>
                    <SelectItem value="picked_up">Picked up</SelectItem>
                    <SelectItem value="delivered">Delivered</SelectItem>
                    <SelectItem value="canceled">Canceled</SelectItem>
                  </SelectContent>
                </Select>
              ) : (
                <Input value={order.status} disabled />
              )}
            </div>

            <div>
              <Label>Boxes Count *</Label>
              <Input
                type="number"
                value={editing ? formData.boxes_count : order.boxes_count}
                onChange={(e) => setFormData({ ...formData, boxes_count: parseInt(e.target.value) })}
                disabled={!editing}
              />
            </div>
          </div>

          <div>
            <Label>Pickup Address *</Label>
            <Input
              value={editing ? formData.pickup_address : order.pickup_address}
              onChange={(e) => setFormData({ ...formData, pickup_address: e.target.value })}
              disabled={!editing}
            />
          </div>

          <div>
            <Label>Delivery Address *</Label>
            <Input
              value={editing ? formData.delivery_address : order.delivery_address}
              onChange={(e) => setFormData({ ...formData, delivery_address: e.target.value })}
              disabled={!editing}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label>Recipient First Name</Label>
              <Input
                value={editing ? formData.recipient_first_name : order.recipient_first_name}
                onChange={(e) => setFormData({ ...formData, recipient_first_name: e.target.value })}
                disabled={!editing}
              />
            </div>

            <div>
              <Label>Recipient Last Name</Label>
              <Input
                value={editing ? formData.recipient_last_name : order.recipient_last_name}
                onChange={(e) => setFormData({ ...formData, recipient_last_name: e.target.value })}
                disabled={!editing}
              />
            </div>
          </div>

          <div>
            <Label>Phone</Label>
            <Input
              value={editing ? formData.phone : order.phone}
              onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
              disabled={!editing}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label>Store ID</Label>
              <Input value={order.store_id} disabled />
            </div>

            <div>
              <Label>Courier ID</Label>
              <Input value={order.courier_id ?? 'Not assigned'} disabled />
            </div>
          </div>
        </div>

        <DialogFooter className="gap-2">
          {editing ? (
            <>
              <Button variant="outline" onClick={() => { setEditing(false); setFormData(order); }}>
                Cancel
              </Button>
              <Button onClick={handleSave} disabled={loading}>
                Save
              </Button>
            </>
          ) : (
            <>
              <Button variant="destructive" onClick={handleDelete} disabled={loading}>
                Delete
              </Button>
              <Button variant="outline" onClick={onClose}>
                Close
              </Button>
              <Button onClick={() => setEditing(true)}>
                Edit
              </Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
