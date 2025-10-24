'use client';

import { useEffect, useState } from 'react';
import { listOrders, listStores, listCouriersAdmin } from '@/lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { IconPackage, IconBuildingStore, IconUser, IconTruck } from '@tabler/icons-react';

export default function DashboardPage() {
  const [stats, setStats] = useState({
    totalOrders: 0,
    activeOrders: 0,
    totalStores: 0,
    activeStores: 0,
    totalCouriers: 0,
    activeCouriers: 0,
    deliveredToday: 0
  });
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    async function loadStats() {
      try {
        const [orders, stores, couriers] = await Promise.all([
          listOrders(),
          listStores(),
          listCouriersAdmin()
        ]);
        
        const today = new Date().toISOString().split('T')[0];
        const deliveredToday = orders.filter(
          (o) =>
            o.status === 'delivered' &&
            o.created_at?.startsWith(today)
        ).length;
        
        const activeOrders = orders.filter(
          (o) => !['delivered', 'canceled'].includes(o.status)
        ).length;
        
        setStats({
          totalOrders: orders.length,
          activeOrders,
          totalStores: stores.length,
          activeStores: stores.filter((s) => s.status === 'active').length,
          totalCouriers: couriers.length,
          activeCouriers: couriers.filter((c) => c.status === 'active').length,
          deliveredToday
        });
      } catch (error) {
        console.error('Failed to load stats:', error);
      } finally {
        setLoading(false);
      }
    }
    
    loadStats();
  }, []);
  
  if (loading) {
    return (
      <div className="flex-1 space-y-4 p-4 md:p-8 pt-6">
        <h2 className="text-3xl font-bold tracking-tight">Dashboard</h2>
        <div className="text-muted-foreground">Loading...</div>
      </div>
    );
  }
  
  return (
    <div className="flex-1 space-y-4 p-4 md:p-8 pt-6">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold tracking-tight">Dashboard</h2>
      </div>
      
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Orders</CardTitle>
            <IconPackage className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalOrders}</div>
            <p className="text-xs text-muted-foreground">
              {stats.activeOrders} active
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Delivered Today</CardTitle>
            <IconTruck className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.deliveredToday}</div>
            <p className="text-xs text-muted-foreground">
              Completed deliveries
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Stores</CardTitle>
            <IconBuildingStore className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalStores}</div>
            <p className="text-xs text-muted-foreground">
              {stats.activeStores} active
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Couriers</CardTitle>
            <IconUser className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalCouriers}</div>
            <p className="text-xs text-muted-foreground">
              {stats.activeCouriers} active
            </p>
          </CardContent>
        </Card>
      </div>
      
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-7">
        <Card className="col-span-4">
          <CardHeader>
            <CardTitle>Quick Stats</CardTitle>
          </CardHeader>
          <CardContent className="pl-2">
            <div className="space-y-4">
              <div className="flex items-center">
                <div className="ml-4 space-y-1">
                  <p className="text-sm font-medium leading-none">
                    Active Orders
                  </p>
                  <p className="text-sm text-muted-foreground">
                    Orders currently in progress
                  </p>
                </div>
                <div className="ml-auto font-medium">{stats.activeOrders}</div>
              </div>
              
              <div className="flex items-center">
                <div className="ml-4 space-y-1">
                  <p className="text-sm font-medium leading-none">
                    Active Couriers
                  </p>
                  <p className="text-sm text-muted-foreground">
                    Couriers available for delivery
                  </p>
                </div>
                <div className="ml-auto font-medium">{stats.activeCouriers}</div>
              </div>
              
              <div className="flex items-center">
                <div className="ml-4 space-y-1">
                  <p className="text-sm font-medium leading-none">
                    Active Stores
                  </p>
                  <p className="text-sm text-muted-foreground">
                    Stores currently operational
                  </p>
                </div>
                <div className="ml-auto font-medium">{stats.activeStores}</div>
              </div>
            </div>
          </CardContent>
        </Card>
        
        <Card className="col-span-3">
          <CardHeader>
            <CardTitle>System Status</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm">Orders System</span>
                <span className="text-sm font-medium text-green-600">Operational</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm">Courier Network</span>
                <span className="text-sm font-medium text-green-600">Operational</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm">Store Network</span>
                <span className="text-sm font-medium text-green-600">Operational</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
