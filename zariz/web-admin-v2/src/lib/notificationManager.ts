import type { OrderEvent } from '@/types/events';

type NotificationItem = {
  id: string;
  event: OrderEvent;
  timestamp: number;
};

class NotificationManager {
  private queue: NotificationItem[] = [];
  private maxVisible = 3;
  private seenIds = new Set<string>();
  private soundEnabled = false;
  private browserNotificationsEnabled = false;
  private audio: HTMLAudioElement | null = null;

  constructor() {
    if (typeof window !== 'undefined') {
      this.loadPreferences();
      this.audio = new Audio('/sounds/notification.wav');
    }
  }

  private loadPreferences() {
    try {
      this.soundEnabled = localStorage.getItem('notifications_sound') === 'true';
      this.browserNotificationsEnabled =
        localStorage.getItem('notifications_browser') === 'true';
    } catch {}
  }

  setSoundEnabled(enabled: boolean) {
    this.soundEnabled = enabled;
    try {
      localStorage.setItem('notifications_sound', String(enabled));
    } catch {}
  }

  setBrowserNotificationsEnabled(enabled: boolean) {
    this.browserNotificationsEnabled = enabled;
    try {
      localStorage.setItem('notifications_browser', String(enabled));
    } catch {}

    if (enabled && typeof window !== 'undefined' && 'Notification' in window) {
      if (Notification.permission === 'default') {
        Notification.requestPermission();
      }
    }
  }

  getSoundEnabled() {
    return this.soundEnabled;
  }

  getBrowserNotificationsEnabled() {
    return this.browserNotificationsEnabled;
  }

  private playSound() {
    if (this.soundEnabled && this.audio) {
      this.audio.play().catch(() => {});
    }
  }

  private showBrowserNotification(event: OrderEvent) {
    if (
      !this.browserNotificationsEnabled ||
      typeof window === 'undefined' ||
      !('Notification' in window)
    ) {
      return;
    }

    if (Notification.permission === 'granted' && document.hidden) {
      new Notification(`New Order #${event.data.order_id}`, {
        body: event.data.pickup_address,
        icon: '/favicon.ico',
        tag: `order-${event.data.order_id}`
      });
    }
  }

  add(event: OrderEvent): boolean {
    const id = `${event.event}-${event.data.order_id}`;

    if (this.seenIds.has(id)) {
      return false;
    }

    this.seenIds.add(id);
    this.queue.push({ id, event, timestamp: Date.now() });

    if (this.queue.length > this.maxVisible) {
      this.queue.shift();
    }

    this.playSound();
    this.showBrowserNotification(event);

    return true;
  }

  remove(id: string) {
    this.queue = this.queue.filter((item) => item.id !== id);
  }

  getVisible(): NotificationItem[] {
    return this.queue.slice(-this.maxVisible);
  }

  clear() {
    this.queue = [];
  }
}

export const notificationManager = new NotificationManager();
