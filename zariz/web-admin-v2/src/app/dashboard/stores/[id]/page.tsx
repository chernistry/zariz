'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { getStore, createStore, updateStore, type StoreDTO } from '@/lib/api';
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
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { toast } from 'sonner';
import { IconArrowLeft } from '@tabler/icons-react';

export default function StoreFormPage() {
  const router = useRouter();
  const params = useParams();
  const isNew = params.id === 'new';
  const storeId = isNew ? null : Number(params.id);
  
  const [loading, setLoading] = useState(!isNew);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState<StoreDTO>({
    name: '',
    status: 'active',
    pickup_address: '',
    box_limit: undefined,
    hours_text: ''
  });
  
  useEffect(() => {
    if (!isNew && storeId) {
      getStore(storeId)
        .then((data) => {
          setForm({
            name: data.name,
            status: data.status,
            pickup_address: data.pickup_address,
            box_limit: data.box_limit,
            hours_text: data.hours_text
          });
        })
        .catch(() => toast.error('Failed to load store'))
        .finally(() => setLoading(false));
    }
  }, [isNew, storeId]);
  
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    
    try {
      if (isNew) {
        await createStore(form);
        toast.success('Store created');
      } else if (storeId) {
        await updateStore(storeId, form);
        toast.success('Store updated');
      }
      router.push('/dashboard/stores');
    } catch (error) {
      toast.error(isNew ? 'Failed to create store' : 'Failed to update store');
    } finally {
      setSaving(false);
    }
  }
  
  if (loading) {
    return <div className="p-8">Loading...</div>;
  }
  
  return (
    <div className="flex-1 space-y-4 p-4 md:p-8 pt-6">
      <Button
        variant="ghost"
        size="sm"
        onClick={() => router.back()}
        className="mb-4"
      >
        <IconArrowLeft className="mr-2 h-4 w-4" />
        Back
      </Button>
      
      <Card>
        <CardHeader>
          <CardTitle>{isNew ? 'New Store' : 'Edit Store'}</CardTitle>
        </CardHeader>
        <CardContent>
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
              <Label htmlFor="status">Status</Label>
              <Select
                value={form.status}
                onValueChange={(value: any) =>
                  setForm({ ...form, status: value })
                }
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
              <Label htmlFor="pickup_address">Pickup Address</Label>
              <Textarea
                id="pickup_address"
                value={form.pickup_address}
                onChange={(e) =>
                  setForm({ ...form, pickup_address: e.target.value })
                }
                rows={3}
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="box_limit">Box Limit</Label>
              <Input
                id="box_limit"
                type="number"
                value={form.box_limit || ''}
                onChange={(e) =>
                  setForm({
                    ...form,
                    box_limit: e.target.value ? Number(e.target.value) : undefined
                  })
                }
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="hours_text">Hours</Label>
              <Input
                id="hours_text"
                value={form.hours_text}
                onChange={(e) =>
                  setForm({ ...form, hours_text: e.target.value })
                }
                placeholder="e.g., Mon-Fri 9AM-5PM"
              />
            </div>
            
            <div className="flex gap-2">
              <Button type="submit" disabled={saving}>
                {saving ? 'Saving...' : 'Save'}
              </Button>
              <Button
                type="button"
                variant="outline"
                onClick={() => router.back()}
              >
                Cancel
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
