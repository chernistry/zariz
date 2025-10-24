'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { listStores, setStoreStatus, type Store } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
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
import { EditStoreDialog } from '@/components/modals/edit-store-dialog';
import { toast } from 'sonner';
import { IconDotsVertical, IconPlus } from '@tabler/icons-react';

export default function StoresPage() {
  const router = useRouter();
  const [stores, setStores] = useState<Store[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [editStoreId, setEditStoreId] = useState<number | null>(null);
  
  async function refresh() {
    try {
      const data = await listStores();
      setStores(data);
    } catch (error) {
      toast.error('Failed to load stores');
    } finally {
      setLoading(false);
    }
  }
  
  useEffect(() => {
    refresh();
  }, []);
  
  async function handleStatusChange(id: number, status: Store['status']) {
    try {
      await setStoreStatus(id, status);
      toast.success('Status updated');
      await refresh();
    } catch (error) {
      toast.error('Failed to update status');
    }
  }
  
  const filteredStores = stores.filter((store) =>
    store.name.toLowerCase().includes(search.toLowerCase())
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
        <h2 className="text-3xl font-bold tracking-tight">Stores</h2>
        <Button onClick={() => router.push('/dashboard/stores/new')}>
          <IconPlus className="mr-2 h-4 w-4" />
          New Store
        </Button>
      </div>
      
      <div className="flex items-center gap-4">
        <Input
          placeholder="Search stores..."
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
                <TableHead>Pickup Address</TableHead>
                <TableHead>Box Limit</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : filteredStores.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center">
                    No stores found
                  </TableCell>
                </TableRow>
              ) : (
                filteredStores.map((store) => (
                  <TableRow key={store.id}>
                    <TableCell>{store.id}</TableCell>
                    <TableCell className="font-medium">{store.name}</TableCell>
                    <TableCell>{getStatusBadge(store.status)}</TableCell>
                    <TableCell className="max-w-xs truncate">
                      {store.pickup_address || '-'}
                    </TableCell>
                    <TableCell>{store.box_limit || '-'}</TableCell>
                    <TableCell className="text-right">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="sm">
                            <IconDotsVertical className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem
                            onClick={() => setEditStoreId(store.id)}
                          >
                            Edit
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => handleStatusChange(store.id, 'active')}
                          >
                            Set Active
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => handleStatusChange(store.id, 'suspended')}
                          >
                            Suspend
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            onClick={() => handleStatusChange(store.id, 'offboarded')}
                          >
                            Offboard
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
      
      <EditStoreDialog
        open={editStoreId !== null}
        storeId={editStoreId}
        onClose={() => setEditStoreId(null)}
        onSuccess={refresh}
      />
    </div>
  );
}
