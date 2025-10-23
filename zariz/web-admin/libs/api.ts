export const API_BASE = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000/v1';

import { authClient } from './authClient';

export async function api(path: string, opts: RequestInit = {}) {
  const token = authClient.getAccessToken() || undefined;
  const headers = {
    'Content-Type': 'application/json',
    ...(opts.headers || {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  } as Record<string, string>;
  const res = await fetch(`${API_BASE}/${path}`, { ...opts, headers });
  if (!res.ok) throw new Error(String(res.status));
  return res.json();
}

export type CourierInfo = {
  id: number;
  name: string;
  capacity_boxes: number;
  load_boxes: number;
  available_boxes: number;
};

export async function getCouriers(availableOnly = true): Promise<CourierInfo[]> {
  return api(`couriers?available_only=${availableOnly ? 1 : 0}`);
}

// Admin APIs
export type Store = {
  id: number;
  name: string;
  status?: 'active'|'suspended'|'offboarded';
  pickup_address?: string;
  box_limit?: number;
  hours_text?: string;
}

export type StoreDTO = {
  name: string;
  status?: 'active'|'suspended'|'offboarded';
  pickup_address?: string;
  box_limit?: number;
  hours_text?: string;
}

export type CourierAdmin = {
  id: number;
  name: string;
  email?: string | null;
  phone?: string | null;
  capacity_boxes?: number;
  status?: 'active'|'suspended'|'offboarded';
}

export type CourierDTO = {
  name: string;
  email?: string;
  phone?: string;
  capacity_boxes?: number;
  status?: 'active'|'suspended'|'offboarded';
  password?: string;
}

export type CredentialsChange = {
  email?: string | null;
  phone?: string | null;
  password?: string;
}

export async function listStores(): Promise<Store[]> { return api('admin/stores') }
export async function getStore(id: number): Promise<Store> { return api(`admin/stores/${id}`) }
export async function createStore(dto: StoreDTO): Promise<{id:number,name:string}> { return api('admin/stores', { method: 'POST', body: JSON.stringify(dto) }) }
export async function updateStore(id: number, dto: StoreDTO): Promise<{ok: boolean}> { return api(`admin/stores/${id}`, { method: 'PATCH', body: JSON.stringify(dto) }) }
export async function setStoreStatus(id: number, status: Store['status']): Promise<{ok:boolean}> { return api(`admin/stores/${id}/status`, { method: 'POST', body: JSON.stringify({ status }) }) }
export async function changeStoreCredentials(id: number, creds: CredentialsChange & { email?: string|null; phone?: string|null }): Promise<{ok:boolean}> {
  return api(`admin/stores/${id}/credentials`, { method: 'POST', body: JSON.stringify(creds) })
}

export async function listCouriersAdmin(): Promise<CourierAdmin[]> { return api('admin/couriers') }
export async function getCourier(id: number): Promise<{id:number,name:string}> { return api(`admin/couriers/${id}`) }
export async function createCourier(dto: CourierDTO): Promise<{id:number,name:string}> { return api('admin/couriers', { method: 'POST', body: JSON.stringify(dto) }) }
export async function updateCourier(id: number, dto: CourierDTO): Promise<{ok:boolean}> { return api(`admin/couriers/${id}`, { method: 'PATCH', body: JSON.stringify(dto) }) }
export async function setCourierStatus(id: number, status: CourierAdmin['status']): Promise<{ok:boolean}> { return api(`admin/couriers/${id}/status`, { method: 'POST', body: JSON.stringify({ status }) }) }
export async function changeCourierCredentials(id: number, creds: CredentialsChange): Promise<{ok:boolean}> { return api(`admin/couriers/${id}/credentials`, { method: 'POST', body: JSON.stringify(creds) }) }
