# Ticket 6-2: Eliminate Duplicate Notifications and Auto-Refresh Orders on SSE

Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first.

**Type:** Bug Fix
**Priority:** High
**Estimated Time:** 1–2 hours

---

## 🎯 Problem Statement

After fixing the SSE token/auth and browser compatibility, two UX issues remain:

1) Duplicate “New Order” notification appears after assigning a courier to that order. A single “New Order” toast shows on creation (correct), but when user clicks Assign in the toast and assigns a courier, another “New Order” toast with the same order id appears. If Assign is clicked again, no further duplicate appears.

2) When deleting an order, a “New Order” toast appears for that deleted order id.

3) Orders table does not refresh automatically on new events. User has to reload the page to see newly created orders or state changes, but we want real-time updates (no full reload).

---

## 🔍 Root Cause Analysis

1) NotificationProvider currently forwards all normalized SSE events to `notificationManager.add(...)` and renders the same `OrderNotification` component (hard-coded “New Order #...”) regardless of event type. As a result:
   - `order.assigned` and other non-created events still trigger a “New Order” toast for the same order id.
   - The second Assign press doesn’t trigger another toast because no new event matching the previous pattern occurs.

   Evidence:
   - `web-admin-v2/src/components/NotificationProvider.tsx` unconditionally calls `notificationManager.add(event)` and then renders `OrderNotification` with the text “New Order”.
   - `web-admin-v2/src/components/OrderNotification.tsx` title is hard-coded as “New Order #{orderId}”.
   - Backend publishes many different event types: `order.created`, `order.assigned`, `order.status_changed`, `order.accepted`, `order.deleted`, `order.updated` (backend/app/api/routes/orders.py: multiple `events_bus.publish(...)`).

2) For deletion, the app treats `order.deleted` just like `order.created` (see 1), causing a “New Order” toast to appear for a deleted id.

3) Orders page (`/dashboard/orders`) loads once and does not subscribe to SSE to refresh on relevant events.

---

## 💡 Solution

Keep the normalized SSE event shape `{ event, data }` from Ticket 6. Then apply minimal, focused changes:

1) Only show “New Order” toast for `order.created` events. Ignore other event types for toasts in NotificationProvider. (Optional future: add specialized toasts per event.)

2) When receiving `order.deleted`, remove any visible notification for that order id (if still present) instead of showing a new toast.

3) Make the Orders page subscribe to admin SSE events and call `refresh()` for specific order-related events so the table updates automatically.

---

## ✍️ Changes

### 1) File: `web-admin-v2/src/components/NotificationProvider.tsx`

Filter events to display toasts only for `order.created`. Also clean up notifications when an order is deleted.

Before (snippet):
```ts
const handleEvent = useCallback((event: any) => {
  const added = notificationManager.add(event);
  if (added) {
    const id = `${event.event}-${event.data.order_id}`;
    setNotifications((prev) => [
      ...prev,
      { id, orderId: event.data.order_id, pickupAddress: event.data.pickup_address }
    ]);
  }
}, []);
```

After:
```ts
const handleEvent = useCallback((event: any) => {
  // Only show toast for new orders
  if (event?.event !== 'order.created') {
    // On deletion, ensure we clear any visible toasts for that order
    if (event?.event === 'order.deleted' && event?.data?.order_id) {
      const idToRemove = `order.created-${event.data.order_id}`;
      notificationManager.remove(idToRemove);
      setNotifications((prev) => prev.filter(n => n.orderId !== event.data.order_id));
    }
    return;
  }

  const added = notificationManager.add(event); // will dedupe by id
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
```

Note: This keeps the existing `OrderNotification` component unchanged and prevents duplicates for non-created events.

Optional (nice-to-have, not required for this ticket): adjust `OrderNotification` to reflect event type with different titles and actions.

### 2) File: `web-admin-v2/src/app/dashboard/orders/page.tsx`

Subscribe to SSE and refresh the table on order-related events.

Add import:
```ts
import { useAdminEvents } from '@/hooks/use-admin-events';
```

Inside component (after `refresh` is defined):
```ts
useAdminEvents((evt) => {
  // Refresh on events that change the list or its visible attributes
  if ([
    'order.created',
    'order.deleted',
    'order.assigned',
    'order.accepted',
    'order.status_changed',
    'order.updated'
  ].includes(evt.event)) {
    refresh();
  }
});
```

This ensures the table updates in near real-time without page reloads.

---

## ✅ Acceptance Criteria

- No duplicate “New Order” toast appears after assigning a courier to a recently created order.
- Deleting an order does not produce a “New Order” toast.
- Creating a new order updates the Orders table automatically within ~1s (no page reload).
- Assigning/canceling/accepting/deleting refreshes the Orders table automatically.
- Existing “New Order” toast auto-dismisses as before; manual Dismiss still works.
- Cross-browser: Chrome/Brave, Firefox, Safari behave consistently.

---

## 🧪 Testing Instructions

1) New Order toast only once
- Open `/dashboard/orders` with DevTools console.
- Create a new order via API or UI.
- Expect one “New Order #<id>” toast. No second toast should appear when assigning a courier to that order.

2) No toast on delete
- With the above order present, delete it from the Orders page.
- Expect: No “New Order” toast for that id.

3) Auto-refresh table
- Keep `/dashboard/orders` open.
- Create a new order via API:
  ```bash
  curl -X POST http://localhost:8000/v1/orders \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_TOKEN" \
    -d '{"store_id": 1, "pickup_address": "Test Address", "delivery_address": "Test Delivery", "boxes_count": 1}'
  ```
- Expect: A new row appears automatically without page reload.
- Assign/cancel/accept/delete an order; verify the table updates automatically.

4) Cross-browser sanity
- Repeat 1–3 in Chrome/Brave, Firefox, and Safari.

---

## 🔄 Rollback Plan

If issues arise:
- Revert NotificationProvider change (file path above) to previous version.
- Remove the `useAdminEvents` subscription block from Orders page.
- Reload the app to confirm behavior is back to prior state.

---

## 📎 Notes

- Event normalization from Ticket 6 remains required so `evt.event` and `evt.data` are always present.
- If we later want richer toasts for non-created events, add separate components or titles (e.g., “Order Assigned”, “Order Deleted”) and show them conditionally instead of ignoring.

