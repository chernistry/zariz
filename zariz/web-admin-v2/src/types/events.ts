export type ConnectionStatus = 'connected' | 'connecting' | 'disconnected';

export type OrderEvent = {
  event: string;
  data: {
    order_id: number;
    store_id: number;
    pickup_address: string;
    delivery_address: string;
    boxes_count: number;
    price_total: number;
    created_at: string;
  };
};

export type SSEEvent = {
  event: string;
  data: any;
};
