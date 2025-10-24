'use client';

import { useState, useEffect } from 'react';
import { listStores, api } from '@/lib/api';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from '@/components/ui/select';
import { toast } from 'sonner';

interface NewOrderDialogProps {
  open: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export function NewOrderDialog({ open, onClose, onSuccess }: NewOrderDialogProps) {
  const [stores, setStores] = useState<Array<{ id: number; name: string }>>([]);
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({
    store_id: '',
    recipient_first_name: '',
    recipient_last_name: '',
    phone: '',
    street: '',
    building_no: '',
    floor: '',
    apartment: '',
    boxes_count: '1',
    pickup_address: '',
    delivery_address: ''
  });
  
  useEffect(() => {
    if (open) {
      listStores()
        .then((data) => setStores(data))
        .catch(() => toast.error('Failed to load stores'));
    }
  }, [open]);
  
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    
    if (!form.store_id) {
      toast.error('Please select a store');
      return;
    }
    
    setLoading(true);
    
    try {
      await api('orders', {
        method: 'POST',
        body: JSON.stringify({
          store_id: Number(form.store_id),
          recipient_first_name: form.recipient_first_name,
          recipient_last_name: form.recipient_last_name,
          phone: form.phone,
          street: form.street,
          building_no: form.building_no,
          floor: form.floor || undefined,
          apartment: form.apartment || undefined,
          boxes_count: Number(form.boxes_count),
          pickup_address: form.pickup_address || undefined,
          delivery_address: form.delivery_address || undefined
        })
      });
      
      toast.success('Order created successfully');
      onSuccess();
      onClose();
      setForm({
        store_id: '',
        recipient_first_name: '',
        recipient_last_name: '',
        phone: '',
        street: '',
        building_no: '',
        floor: '',
        apartment: '',
        boxes_count: '1',
        pickup_address: '',
        delivery_address: ''
      });
    } catch (error) {
      toast.error('Failed to create order');
    } finally {
      setLoading(false);
    }
  }
  
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Create New Order</DialogTitle>
          <DialogDescription>
            Fill in the order details below
          </DialogDescription>
        </DialogHeader>
        
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="store_id">Store *</Label>
            <Select
              value={form.store_id}
              onValueChange={(value) => setForm({ ...form, store_id: value })}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select store" />
              </SelectTrigger>
              <SelectContent>
                {stores.length === 0 ? (
                  <SelectItem value="none" disabled>
                    No stores available
                  </SelectItem>
                ) : (
                  stores.map((store) => (
                    <SelectItem key={store.id} value={String(store.id)}>
                      {store.name}
                    </SelectItem>
                  ))
                )}
              </SelectContent>
            </Select>
          </div>
          
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="recipient_first_name">First Name *</Label>
              <Input
                id="recipient_first_name"
                value={form.recipient_first_name}
                onChange={(e) =>
                  setForm({ ...form, recipient_first_name: e.target.value })
                }
                required
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="recipient_last_name">Last Name *</Label>
              <Input
                id="recipient_last_name"
                value={form.recipient_last_name}
                onChange={(e) =>
                  setForm({ ...form, recipient_last_name: e.target.value })
                }
                required
              />
            </div>
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="phone">Phone *</Label>
            <Input
              id="phone"
              value={form.phone}
              onChange={(e) => setForm({ ...form, phone: e.target.value })}
              required
            />
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="street">Street *</Label>
            <Input
              id="street"
              value={form.street}
              onChange={(e) => setForm({ ...form, street: e.target.value })}
              required
            />
          </div>
          
          <div className="grid grid-cols-3 gap-4">
            <div className="space-y-2">
              <Label htmlFor="building_no">Building *</Label>
              <Input
                id="building_no"
                value={form.building_no}
                onChange={(e) =>
                  setForm({ ...form, building_no: e.target.value })
                }
                required
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="floor">Floor</Label>
              <Input
                id="floor"
                value={form.floor}
                onChange={(e) => setForm({ ...form, floor: e.target.value })}
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="apartment">Apartment</Label>
              <Input
                id="apartment"
                value={form.apartment}
                onChange={(e) => setForm({ ...form, apartment: e.target.value })}
              />
            </div>
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="boxes_count">Boxes Count *</Label>
            <Input
              id="boxes_count"
              type="number"
              min="1"
              value={form.boxes_count}
              onChange={(e) => setForm({ ...form, boxes_count: e.target.value })}
              required
            />
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="pickup_address">Pickup Address *</Label>
            <Textarea
              id="pickup_address"
              value={form.pickup_address}
              onChange={(e) =>
                setForm({ ...form, pickup_address: e.target.value })
              }
              rows={2}
              required
            />
          </div>
          
          <div className="space-y-2">
            <Label htmlFor="delivery_address">Delivery Address *</Label>
            <Textarea
              id="delivery_address"
              value={form.delivery_address}
              onChange={(e) =>
                setForm({ ...form, delivery_address: e.target.value })
              }
              rows={2}
              required
            />
          </div>
          
          <div className="flex gap-2 justify-end">
            <Button type="button" variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" disabled={loading}>
              {loading ? 'Creating...' : 'Create Order'}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
