'use client';

import { useState, useEffect } from 'react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Button } from '@/components/ui/button';
import { notificationManager } from '@/lib/notificationManager';

type NotificationSettingsDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
};

export function NotificationSettingsDialog({
  open,
  onOpenChange
}: NotificationSettingsDialogProps) {
  const [soundEnabled, setSoundEnabled] = useState(false);
  const [browserEnabled, setBrowserEnabled] = useState(false);

  useEffect(() => {
    if (open) {
      setSoundEnabled(notificationManager.getSoundEnabled());
      setBrowserEnabled(notificationManager.getBrowserNotificationsEnabled());
    }
  }, [open]);

  const handleSoundToggle = (checked: boolean) => {
    setSoundEnabled(checked);
    notificationManager.setSoundEnabled(checked);
  };

  const handleBrowserToggle = (checked: boolean) => {
    setBrowserEnabled(checked);
    notificationManager.setBrowserNotificationsEnabled(checked);
  };

  const testSound = () => {
    const audio = new Audio('/sounds/notification.wav');
    audio.play().catch(() => alert('Sound playback failed'));
  };

  const testBrowserNotification = () => {
    if (!('Notification' in window)) {
      alert('Browser notifications not supported');
      return;
    }

    if (Notification.permission === 'granted') {
      new Notification('Test Notification', {
        body: 'This is a test notification from Zariz',
        icon: '/favicon.ico'
      });
    } else if (Notification.permission !== 'denied') {
      Notification.requestPermission().then((permission) => {
        if (permission === 'granted') {
          new Notification('Test Notification', {
            body: 'This is a test notification from Zariz',
            icon: '/favicon.ico'
          });
        }
      });
    } else {
      alert('Notification permission denied. Enable in browser settings.');
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Notification Settings</DialogTitle>
          <DialogDescription>
            Configure how you receive order notifications
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4 py-4">
          <div className="flex items-center justify-between">
            <div className="space-y-0.5 flex-1">
              <Label htmlFor="sound">Sound Notifications</Label>
              <p className="text-sm text-muted-foreground">
                Play a sound when new orders arrive
              </p>
            </div>
            <div className="flex items-center gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={testSound}
              >
                Test
              </Button>
              <Switch
                id="sound"
                checked={soundEnabled}
                onCheckedChange={handleSoundToggle}
              />
            </div>
          </div>
          <div className="flex items-center justify-between">
            <div className="space-y-0.5 flex-1">
              <Label htmlFor="browser">Browser Notifications</Label>
              <p className="text-sm text-muted-foreground">
                Show system notifications when tab is inactive
              </p>
            </div>
            <div className="flex items-center gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={testBrowserNotification}
              >
                Test
              </Button>
              <Switch
                id="browser"
                checked={browserEnabled}
                onCheckedChange={handleBrowserToggle}
              />
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
