'use client';

import { useState, useCallback } from 'react';
import { useAdminEvents } from '@/hooks/use-admin-events';
import { notificationManager } from '@/lib/notificationManager';
import { OrderNotification } from './OrderNotification';
import { ConnectionStatus } from './ConnectionStatus';
import { AssignCourierDialog } from './modals/assign-courier-dialog';
import { assignOrder } from '@/lib/api';
import { toast } from 'sonner';

export function NotificationProvider({ children }: { children: React.ReactNode }) {
  const [notifications, setNotifications] = useState<Array<{ id: string; orderId: number; pickupAddress: string }>>([]);
  const [assignOrderId, setAssignOrderId] = useState<number | null>(null);

  const handleEvent = useCallback((event: any) => {
    if (event?.event !== 'order.created') {
      if (event?.event === 'order.deleted' && event?.data?.order_id) {
        const idToRemove = `order.created-${event.data.order_id}`;
        notificationManager.remove(idToRemove);
        setNotifications((prev) => prev.filter(n => n.orderId !== event.data.order_id));
      }
      return;
    }

    const added = notificationManager.add(event);
    if (added) {
      const id = `${event.event}-${event.data.order_id}`;
      setNotifications((prev) => [
        ...prev,
        {
          id,
          orderId: event.data.order_id,
          pickupAddress: event.data.pickup_address || ''
        }
      ]);
    }
  }, []);

  const { status } = useAdminEvents(handleEvent);

  const handleDismiss = useCallback((id: string) => {
    notificationManager.remove(id);
    setNotifications((prev) => prev.filter((n) => n.id !== id));
  }, []);

  const handleAssign = useCallback((orderId: number) => {
    setAssignOrderId(orderId);
  }, []);

  const handleCourierSelect = useCallback(async (courierId: number) => {
    if (!assignOrderId) return;
    try {
      await assignOrder(assignOrderId, courierId);
      toast.success('Order assigned successfully');
      setAssignOrderId(null);
    } catch (error) {
      toast.error('Failed to assign order');
    }
  }, [assignOrderId]);

  return (
    <>
      <div className="fixed bottom-4 right-4 z-40">
        <ConnectionStatus status={status} />
      </div>
      {notifications.map((notification, index) => (
        <div
          key={notification.id}
          style={{ top: `${1 + index * 5.5}rem` }}
          className="fixed right-4 z-50"
        >
          <OrderNotification
            orderId={notification.orderId}
            pickupAddress={notification.pickupAddress}
            onAssign={() => handleAssign(notification.orderId)}
            onDismiss={() => handleDismiss(notification.id)}
          />
        </div>
      ))}
      <AssignCourierDialog
        open={!!assignOrderId}
        orderId={assignOrderId}
        onClose={() => setAssignOrderId(null)}
        onSelect={handleCourierSelect}
      />
      {children}
    </>
  );
}
