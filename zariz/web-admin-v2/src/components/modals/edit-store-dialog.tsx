'use client';

import { useEffect, useState } from 'react';
import { getStore, updateStore, setStoreCredentials, type StoreDTO } from '@/lib/api';
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
  storeId: number | null;
  onClose: () => void;
  onSuccess: () => void;
};

export function EditStoreDialog({ open, storeId, onClose, onSuccess }: Props) {
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState<StoreDTO & { password?: string }>({
    name: '',
    status: 'active',
    pickup_address: '',
    box_limit: undefined,
    hours_text: '',
    password: ''
  });
  const [credentials, setCredentials] = useState({ email: '', phone: '', password: '' });
  
  useEffect(() => {
    if (open && storeId) {
      setLoading(true);
      getStore(storeId)
        .then((data) => {
          setForm({
            name: data.name,
            status: data.status,
            pickup_address: data.pickup_address || '',
            box_limit: data.box_limit,
            hours_text: data.hours_text || '',
            password: ''
          });
        })
        .catch(() => toast.error('Failed to load store'))
        .finally(() => setLoading(false));
    }
  }, [open, storeId]);
  
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!storeId) return;
    
    setSaving(true);
    try {
      await updateStore(storeId, {
        name: form.name,
        status: form.status,
        pickup_address: form.pickup_address,
        box_limit: form.box_limit,
        hours_text: form.hours_text
      });
      
      if (credentials.email || credentials.phone || credentials.password) {
        await setStoreCredentials(storeId, credentials);
      }
      
      toast.success('Store updated');
      onSuccess();
      onClose();
    } catch (error) {
      toast.error('Failed to update store');
    } finally {
      setSaving(false);
    }
  }
  
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-md max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Edit Store</DialogTitle>
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
              <Label htmlFor="pickup_address">Pickup Address</Label>
              <Input
                id="pickup_address"
                value={form.pickup_address}
                onChange={(e) => setForm({ ...form, pickup_address: e.target.value })}
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="box_limit">Box Limit</Label>
              <Input
                id="box_limit"
                type="number"
                value={form.box_limit || ''}
                onChange={(e) =>
                  setForm({ ...form, box_limit: e.target.value ? Number(e.target.value) : undefined })
                }
                min={1}
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="hours_text">Hours</Label>
              <Input
                id="hours_text"
                value={form.hours_text}
                onChange={(e) => setForm({ ...form, hours_text: e.target.value })}
                placeholder="e.g. Mon-Fri 9-17"
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
            
            <div className="border-t pt-4 space-y-4">
              <h4 className="font-medium">Store Credentials (optional)</h4>
              
              <div className="space-y-2">
                <Label htmlFor="cred_email">Email</Label>
                <Input
                  id="cred_email"
                  type="email"
                  value={credentials.email}
                  onChange={(e) => setCredentials({ ...credentials, email: e.target.value })}
                  placeholder="Leave empty to keep current"
                />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="cred_phone">Phone</Label>
                <Input
                  id="cred_phone"
                  value={credentials.phone}
                  onChange={(e) => setCredentials({ ...credentials, phone: e.target.value })}
                  placeholder="Leave empty to keep current"
                />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="cred_password">New Password</Label>
                <Input
                  id="cred_password"
                  type="password"
                  value={credentials.password}
                  onChange={(e) => setCredentials({ ...credentials, password: e.target.value })}
                  placeholder="Leave empty to keep current"
                />
              </div>
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
