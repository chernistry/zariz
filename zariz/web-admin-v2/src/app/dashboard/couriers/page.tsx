'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { listCouriersAdmin, setCourierStatus, getCouriers, type CourierAdmin, type CourierInfo } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Progress } from '@/components/ui/progress';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow
} from '@/components/ui/table';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger
} from '@/components/ui/dropdown-menu';
import { EditCourierDialog } from '@/components/modals/edit-courier-dialog';
import { toast } from 'sonner';
import { IconDotsVertical, IconPlus } from '@tabler/icons-react';

export default function CouriersPage() {
  const router = useRouter();
  const [couriers, setCouriers] = useState<CourierAdmin[]>([]);
  const [courierLoads, setCourierLoads] = useState<Map<number, CourierInfo>>(new Map());
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [editCourierId, setEditCourierId] = useState<number | null>(null);
  
  async function refresh() {
    try {
      const [adminData, loadData] = await Promise.all([
        listCouriersAdmin(),
        getCouriers(false)
      ]);
      setCouriers(adminData);
      
      const loadMap = new Map<number, CourierInfo>();
      loadData.forEach(c => loadMap.set(c.id, c));
      setCourierLoads(loadMap);
    } catch (error) {
      toast.error('Failed to load couriers');
    } finally {
      setLoading(false);
    }
  }
  
  useEffect(() => {
    refresh();
  }, []);
  
  async function handleStatusChange(id: number, status: CourierAdmin['status']) {
    try {
      await setCourierStatus(id, status);
      toast.success('Status updated');
      await refresh();
    } catch (error) {
      toast.error('Failed to update status');
    }
  }
  
  const filteredCouriers = couriers.filter((courier) =>
    courier.name.toLowerCase().includes(search.toLowerCase())
  );
  
  function getStatusBadge(status?: string) {
    switch (status) {
      case 'active':
        return <Badge variant="default">Active</Badge>;
      case 'suspended':
        return <Badge variant="secondary">Suspended</Badge>;
      case 'offboarded':
        return <Badge variant="destructive">Offboarded</Badge>;
      default:
        return <Badge variant="outline">Unknown</Badge>;
    }
  }
  
  return (
    <div className="flex-1 space-y-4 p-4 md:p-8 pt-6">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold tracking-tight">Couriers</h2>
        <Button onClick={() => router.push('/dashboard/couriers/new')}>
          <IconPlus className="mr-2 h-4 w-4" />
          New Courier
        </Button>
      </div>
      
      <div className="flex items-center gap-4">
        <Input
          placeholder="Search couriers..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="max-w-sm"
        />
      </div>
      
      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>ID</TableHead>
                <TableHead>Name</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Current Load</TableHead>
                <TableHead>Email</TableHead>
                <TableHead>Phone</TableHead>
                <TableHead>Capacity</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={8} className="text-center">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : filteredCouriers.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={8} className="text-center">
                    No couriers found
                  </TableCell>
                </TableRow>
              ) : (
                filteredCouriers.map((courier) => {
                  const loadInfo = courierLoads.get(courier.id);
                  const loadPct = loadInfo 
                    ? (loadInfo.load_boxes / loadInfo.capacity_boxes) * 100 
                    : 0;
                  
                  return (
                    <TableRow key={courier.id}>
                      <TableCell>{courier.id}</TableCell>
                      <TableCell className="font-medium">{courier.name}</TableCell>
                      <TableCell>{getStatusBadge(courier.status)}</TableCell>
                      <TableCell>
                        {loadInfo ? (
                          <div className="space-y-1 min-w-[150px]">
                            <div className="flex items-center justify-between text-sm">
                              <span>{loadInfo.load_boxes}/{loadInfo.capacity_boxes} boxes</span>
                            </div>
                            <Progress value={loadPct} className="h-2" />
                          </div>
                        ) : (
                          <span className="text-muted-foreground">-</span>
                        )}
                      </TableCell>
                      <TableCell>{courier.email || '-'}</TableCell>
                      <TableCell>{courier.phone || '-'}</TableCell>
                      <TableCell>{courier.capacity_boxes || 8}</TableCell>
                      <TableCell className="text-right">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="sm">
                            <IconDotsVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem
                            onClick={() => setEditCourierId(courier.id)}
                          >
                            Edit
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => handleStatusChange(courier.id, 'active')}
                          >
                            Set Active
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => handleStatusChange(courier.id, 'suspended')}
                          >
                            Suspend
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => handleStatusChange(courier.id, 'offboarded')}
                          >
                            Offboard
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
      
      <EditCourierDialog
        open={editCourierId !== null}
        courierId={editCourierId}
        onClose={() => setEditCourierId(null)}
        onSuccess={refresh}
      />
    </div>
  );
}
