'use client';

import { useEffect, useState } from 'react';
import { getCouriers, type CourierInfo, getOrder } from '@/lib/api';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Progress } from '@/components/ui/progress';
import { Badge } from '@/components/ui/badge';
import { IconLoader2 } from '@tabler/icons-react';

interface AssignCourierDialogProps {
  open: boolean;
  orderId?: string | number | null;
  onClose: () => void;
  onSelect: (courierId: number) => void;
}

export function AssignCourierDialog({
  open,
  orderId,
  onClose,
  onSelect
}: AssignCourierDialogProps) {
  const [couriers, setCouriers] = useState<CourierInfo[]>([]);
  const [loading, setLoading] = useState(false);
  const [orderBoxes, setOrderBoxes] = useState(0);
  
  useEffect(() => {
    if (open) {
      setLoading(true);
      Promise.all([
        getCouriers(true),
        orderId ? getOrder(orderId).then(o => o.boxes_count || 0) : Promise.resolve(0)
      ])
        .then(([courierData, boxes]) => {
          // Sort by available capacity (most available first)
          const sorted = courierData.sort((a, b) => b.available_boxes - a.available_boxes);
          setCouriers(sorted);
          setOrderBoxes(boxes);
        })
        .catch(() => {
          setCouriers([]);
          setOrderBoxes(0);
        })
        .finally(() => setLoading(false));
    }
  }, [open, orderId]);
  
  function getLoadPercentage(courier: CourierInfo) {
    return ((courier.load_boxes / courier.capacity_boxes) * 100);
  }
  
  function getLoadColor(percentage: number) {
    if (percentage < 50) return 'bg-green-500';
    if (percentage < 80) return 'bg-yellow-500';
    return 'bg-red-500';
  }
  
  function canAssign(courier: CourierInfo) {
    return courier.available_boxes >= orderBoxes;
  }
  
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Assign Courier</DialogTitle>
          <DialogDescription>
            Select an available courier to assign this order
            {orderBoxes > 0 && (
              <Badge variant="secondary" className="ml-2">
                This order: {orderBoxes} boxes
              </Badge>
            )}
          </DialogDescription>
        </DialogHeader>
        
        {loading ? (
          <div className="flex items-center justify-center py-8">
            <IconLoader2 className="h-6 w-6 animate-spin" />
          </div>
        ) : (
          <ScrollArea className="max-h-[500px]">
            <div className="space-y-3">
              {couriers.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">
                  No available couriers
                </p>
              ) : (
                couriers.map((courier) => {
                  const loadPct = getLoadPercentage(courier);
                  const canAssignOrder = canAssign(courier);
                  
                  return (
                    <div
                      key={courier.id}
                      className={`border rounded-lg p-4 space-y-2 ${
                        !canAssignOrder ? 'opacity-50' : ''
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="font-medium">{courier.name}</span>
                        <span className="text-sm text-muted-foreground">
                          {courier.load_boxes}/{courier.capacity_boxes} boxes
                        </span>
                      </div>
                      
                      <Progress 
                        value={loadPct} 
                        className="h-2"
                      />
                      
                      <div className="flex items-center justify-between text-xs">
                        <span className="text-muted-foreground">
                          Available: {courier.available_boxes}/{courier.capacity_boxes} boxes ({Math.round(100 - loadPct)}% free)
                        </span>
                        <Badge 
                          variant={loadPct < 50 ? 'default' : loadPct < 80 ? 'secondary' : 'destructive'}
                          className="text-xs"
                        >
                          {loadPct < 50 ? 'Low' : loadPct < 80 ? 'Medium' : 'High'} load
                        </Badge>
                      </div>
                      
                      <Button
                        variant="outline"
                        className="w-full"
                        disabled={!canAssignOrder}
                        onClick={() => {
                          onSelect(courier.id);
                          onClose();
                        }}
                      >
                        {canAssignOrder ? 'Assign' : 'Insufficient capacity'}
                      </Button>
                    </div>
                  );
                })
              )}
            </div>
          </ScrollArea>
        )}
      </DialogContent>
    </Dialog>
  );
}
