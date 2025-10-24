'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { getCourier, createCourier, updateCourier, type CourierDTO } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
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

export default function CourierFormPage() {
  const router = useRouter();
  const params = useParams();
  const isNew = params.id === 'new';
  const courierId = isNew ? null : Number(params.id);
  
  const [loading, setLoading] = useState(!isNew);
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
    if (!isNew && courierId) {
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
  }, [isNew, courierId]);
  
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    
    try {
      const dto = { ...form };
      if (!isNew) delete dto.password;
      
      if (isNew) {
        await createCourier(dto);
        toast.success('Courier created');
      } else if (courierId) {
        await updateCourier(courierId, dto);
        toast.success('Courier updated');
      }
      router.push('/dashboard/couriers');
    } catch (error) {
      toast.error(isNew ? 'Failed to create courier' : 'Failed to update courier');
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
          <CardTitle>{isNew ? 'New Courier' : 'Edit Courier'}</CardTitle>
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
                  setForm({
                    ...form,
                    capacity_boxes: Number(e.target.value)
                  })
                }
                min={1}
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
            
            {isNew && (
              <div className="space-y-2">
                <Label htmlFor="password">Password *</Label>
                <Input
                  id="password"
                  type="password"
                  value={form.password}
                  onChange={(e) => setForm({ ...form, password: e.target.value })}
                  required={isNew}
                />
              </div>
            )}
            
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
