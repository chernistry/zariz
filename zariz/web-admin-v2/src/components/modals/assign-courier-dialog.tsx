'use client';

import { useEffect, useState } from 'react';
import { getCouriers, type CourierInfo } from '@/lib/api';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { IconLoader2 } from '@tabler/icons-react';

interface AssignCourierDialogProps {
  open: boolean;
  onClose: () => void;
  onSelect: (courierId: number) => void;
}

export function AssignCourierDialog({
  open,
  onClose,
  onSelect
}: AssignCourierDialogProps) {
  const [couriers, setCouriers] = useState<CourierInfo[]>([]);
  const [loading, setLoading] = useState(false);
  
  useEffect(() => {
    if (open) {
      setLoading(true);
      getCouriers(true)
        .then(setCouriers)
        .catch(() => setCouriers([]))
        .finally(() => setLoading(false));
    }
  }, [open]);
  
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Assign Courier</DialogTitle>
          <DialogDescription>
            Select an available courier to assign this order
          </DialogDescription>
        </DialogHeader>
        
        {loading ? (
          <div className="flex items-center justify-center py-8">
            <IconLoader2 className="h-6 w-6 animate-spin" />
          </div>
        ) : (
          <ScrollArea className="max-h-[400px]">
            <div className="space-y-2">
              {couriers.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-4">
                  No available couriers
                </p>
              ) : (
                couriers.map((courier) => (
                  <Button
                    key={courier.id}
                    variant="outline"
                    className="w-full justify-between"
                    onClick={() => {
                      onSelect(courier.id);
                      onClose();
                    }}
                  >
                    <span>{courier.name}</span>
                    <span className="text-xs text-muted-foreground">
                      {courier.available_boxes}/{courier.capacity_boxes} boxes
                    </span>
                  </Button>
                ))
              )}
            </div>
          </ScrollArea>
        )}
      </DialogContent>
    </Dialog>
  );
}
