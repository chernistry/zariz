type EventHandler = (event: any) => void;

class EventBus {
  private handlers: Set<EventHandler> = new Set();

  subscribe(handler: EventHandler) {
    this.handlers.add(handler);
    return () => {
      this.handlers.delete(handler);
    };
  }

  publish(event: any) {
    this.handlers.forEach(handler => handler(event));
  }
}

export const eventBus = new EventBus();
