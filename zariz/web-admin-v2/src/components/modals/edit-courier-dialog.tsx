'use client';

import { useEffect, useState } from 'react';
import { getCourier, updateCourier, setCourierCredentials, type CourierDTO } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from '@/components/ui/select';
import { toast } from 'sonner';

type Props = {
  open: boolean;
  courierId: number | null;
  onClose: () => void;
  onSuccess: () => void;
};

export function EditCourierDialog({ open, courierId, onClose, onSuccess }: Props) {
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState<CourierDTO>({
    name: '',
    email: '',
    phone: '',
    capacity_boxes: 8,
    status: 'active',
    password: ''
  });
  
  useEffect(() => {
    if (open && courierId) {
      setLoading(true);
      getCourier(courierId)
        .then((data) => {
          setForm({
            name: data.name,
            email: data.email || '',
            phone: data.phone || '',
            capacity_boxes: data.capacity_boxes || 8,
            status: data.status,
            password: ''
          });
        })
        .catch(() => toast.error('Failed to load courier'))
        .finally(() => setLoading(false));
    }
  }, [open, courierId]);
  
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!courierId) return;
    
    setSaving(true);
    try {
      await updateCourier(courierId, {
        name: form.name,
        email: form.email,
        phone: form.phone,
        capacity_boxes: form.capacity_boxes,
        status: form.status
      });
      
      if (form.password) {
        await setCourierCredentials(courierId, { password: form.password });
      }
      
      toast.success('Courier updated');
      onSuccess();
      onClose();
    } catch (error) {
      toast.error('Failed to update courier');
    } finally {
      setSaving(false);
    }
  }
  
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Edit Courier</DialogTitle>
        </DialogHeader>
        
        {loading ? (
          <div className="py-8 text-center">Loading...</div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">Name *</Label>
              <Input
                id="name"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                required
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="phone">Phone</Label>
              <Input
                id="phone"
                value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="capacity_boxes">Capacity (boxes)</Label>
              <Input
                id="capacity_boxes"
                type="number"
                value={form.capacity_boxes}
                onChange={(e) =>
                  setForm({ ...form, capacity_boxes: Number(e.target.value) })
                }
                min={1}
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="status">Status</Label>
              <Select
                value={form.status}
                onValueChange={(value: any) => setForm({ ...form, status: value })}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="active">Active</SelectItem>
                  <SelectItem value="suspended">Suspended</SelectItem>
                  <SelectItem value="offboarded">Offboarded</SelectItem>
                </SelectContent>
              </Select>
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="password">New Password (leave empty to keep current)</Label>
              <Input
                id="password"
                type="password"
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                placeholder="Leave empty to keep current"
              />
            </div>
            
            <div className="flex gap-2 justify-end">
              <Button type="button" variant="outline" onClick={onClose}>
                Cancel
              </Button>
              <Button type="submit" disabled={saving}>
                {saving ? 'Saving...' : 'Save'}
              </Button>
            </div>
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
}
