import { authClient } from './auth-client';

export const API_BASE = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000/v1';

export async function api(path: string, opts: RequestInit = {}) {
  const run = async (): Promise<Response> => {
    const token = authClient.getAccessToken() || undefined;
    const headers = {
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    } as Record<string, string>;
    
    return fetch(`${API_BASE}/${path}`, { ...opts, headers });
  };
  
  let res = await run();
  
  if (res.status === 401) {
    try {
      await authClient.refresh();
      res = await run();
    } catch {}
  }
  
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(text || String(res.status));
  }
  
  return res.json();
}

export type Order = {
  id: string | number;
  status: string;
  store_id?: number;
  courier_id?: number | null;
  created_at?: string;
  pickup_address?: string;
  delivery_address?: string;
  recipient_first_name?: string;
  recipient_last_name?: string;
  phone?: string;
  boxes_count?: number;
};

export type CourierInfo = {
  id: number;
  name: string;
  capacity_boxes: number;
  load_boxes: number;
  available_boxes: number;
};

export type Store = {
  id: number;
  name: string;
  status?: 'active' | 'suspended' | 'offboarded';
  pickup_address?: string;
  box_limit?: number;
  hours_text?: string;
};

export type CourierAdmin = {
  id: number;
  name: string;
  email?: string | null;
  phone?: string | null;
  capacity_boxes?: number;
  status?: 'active' | 'suspended' | 'offboarded';
};

export async function listOrders(params?: Record<string, string>): Promise<Order[]> {
  const query = params ? `?${new URLSearchParams(params)}` : '';
  return api(`orders${query}`);
}

export async function getOrder(id: string | number): Promise<Order> {
  return api(`orders/${id}`);
}

export async function assignOrder(id: string | number, courierId: number): Promise<{ ok: boolean }> {
  return api(`orders/${id}/assign`, {
    method: 'POST',
    body: JSON.stringify({ courier_id: courierId })
  });
}

export async function cancelOrder(id: string | number, reason: string): Promise<{ ok: boolean }> {
  return api(`orders/${id}/cancel`, {
    method: 'POST',
    body: JSON.stringify({ reason })
  });
}

export async function deleteOrder(id: string | number): Promise<{ ok: boolean }> {
  return api(`orders/${id}`, { method: 'DELETE' });
}

export async function getCouriers(availableOnly = true): Promise<CourierInfo[]> {
  return api(`couriers?available_only=${availableOnly ? 1 : 0}`);
}

export async function listCouriersAdmin(): Promise<CourierAdmin[]> {
  return api('admin/couriers');
}

export async function listStores(): Promise<Store[]> {
  return api('admin/stores');
}

export type StoreDTO = {
  name: string;
  status?: 'active' | 'suspended' | 'offboarded';
  pickup_address?: string;
  box_limit?: number;
  hours_text?: string;
};

export type CourierDTO = {
  name: string;
  email?: string;
  phone?: string;
  capacity_boxes?: number;
  status?: 'active' | 'suspended' | 'offboarded';
  password?: string;
};

export async function getStore(id: number): Promise<Store> {
  return api(`admin/stores/${id}`);
}

export async function createStore(dto: StoreDTO): Promise<{ id: number; name: string }> {
  return api('admin/stores', {
    method: 'POST',
    body: JSON.stringify(dto)
  });
}

export async function updateStore(id: number, dto: StoreDTO): Promise<{ ok: boolean }> {
  return api(`admin/stores/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(dto)
  });
}

export async function setStoreStatus(
  id: number,
  status: Store['status']
): Promise<{ ok: boolean }> {
  return api(`admin/stores/${id}/status`, {
    method: 'POST',
    body: JSON.stringify({ status })
  });
}

export async function getCourier(id: number): Promise<CourierAdmin> {
  return api(`admin/couriers/${id}`);
}

export async function createCourier(dto: CourierDTO): Promise<{ id: number; name: string }> {
  return api('admin/couriers', {
    method: 'POST',
    body: JSON.stringify(dto)
  });
}

export async function updateCourier(id: number, dto: CourierDTO): Promise<{ ok: boolean }> {
  return api(`admin/couriers/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(dto)
  });
}

export async function setCourierStatus(
  id: number,
  status: CourierAdmin['status']
): Promise<{ ok: boolean }> {
  return api(`admin/couriers/${id}/status`, {
    method: 'POST',
    body: JSON.stringify({ status })
  });
}

export async function getCourierLoad(id: number): Promise<CourierInfo> {
  return api(`couriers/${id}/load`);
}

export async function setCourierCredentials(
  id: number,
  credentials: { email?: string; phone?: string; password?: string }
): Promise<{ ok: boolean }> {
  return api(`admin/couriers/${id}/credentials`, {
    method: 'POST',
    body: JSON.stringify(credentials)
  });
}

export async function setStoreCredentials(
  id: number,
  credentials: { email?: string; phone?: string; password?: string }
): Promise<{ ok: boolean }> {
  return api(`admin/stores/${id}/credentials`, {
    method: 'POST',
    body: JSON.stringify(credentials)
  });
}

