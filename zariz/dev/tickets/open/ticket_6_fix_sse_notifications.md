# Ticket 6: Fix SSE Notifications - 401 Errors & Browser Test
Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first.
**Type:** Bug Fix
**Priority:** High
**Estimated Time:** 2-3 hours

---

## 🎯 Problem Statement

SSE notifications are failing with 401 Unauthorized errors, preventing real-time order notifications. Investigation shows EventSource connections are made without authentication tokens. Additionally, the browser notification test fails silently, providing no feedback to the user.

### Issues Identified

1.  **SSE 401 Errors**: Requests to `/v1/events/sse` have empty query strings (no token).
2.  **No Real-time Notifications**: Orders don't trigger notifications due to the failed SSE connection.
3.  **Browser Notification Test Silent Failure**: The "Test" button for browser notifications produces no visible result or feedback.
4.  **Token Expiration Handling**: No mechanism to refresh tokens during long-lived SSE connections

### Evidence
- HAR file shows: `http://localhost:8000/v1/events/sse` with `"queryString": []`
- Console logs: `[SSE] Error:` but no `[SSE] Message received:`
- Manual SSE test with token works: `new EventSource(url + '?token=' + token)`
- Unused SSE hook found at `/src/hooks/use-sse.ts`

---

## 🔧 Root Cause Analysis

### Issue 1: Auth Initialization Race Condition
**Files**: `/src/hooks/use-auth.ts`, `/src/hooks/use-admin-events.ts`

**Problem**: The `useAuth` hook initializes with `authClient.getAccessToken()` but then calls `authClient.init()` which may clear an expired token. This creates a race condition where:
1. `useAuth` initially returns a token from localStorage
2. `useAdminEvents` starts connecting with this token
3. `authClient.init()` discovers the token is expired and clears it
4. SSE connection fails with 401 because it used the expired token

**Current Code in use-auth.ts**:
```typescript
const [token, setToken] = useState<string | null>(authClient.getAccessToken()); // May be expired
const [loading, setLoading] = useState(true);

useEffect(() => {
  authClient.init().finally(() => { // This may clear the token if expired
    setToken(authClient.getAccessToken());
    setClaims(authClient.getClaims());
    setLoading(false);
  });
}, []);
```

**Current Code in use-admin-events.ts**:
```typescript
useEffect(() => {
  if (loading || !isAuthenticated || !token) { // token may be expired here
    return;
  }
  const connect = () => {
    const url = `${API_BASE}/events/sse?token=${token}`; // Uses potentially expired token
    const eventSource = new EventSource(url);
  };
}, [token, isAuthenticated, loading, onEvent]);
```

### Issue 2: Token Expiration During SSE Connection
**File**: `/src/hooks/use-admin-events.ts`

**Problem**: Long-lived SSE connections don't handle token expiration. If a token expires during an active connection, the connection continues but any reconnection attempts will fail with 401.

### Issue 3: Browser Notification Test Silent Failures
**File**: `/src/components/modals/notification-settings-dialog.tsx`

**Problem**: The `testBrowserNotification` function lacks proper error handling and user feedback. Browser notifications can fail silently due to:
- Focus requirements (tab must be visible)
- Browser-specific restrictions
- JavaScript errors during notification creation
- Permission state changes

### Issue 4: Unused Code
**File**: `/src/hooks/use-sse.ts`

**Problem**: This file exists but is not used anywhere in the codebase, creating dead code that should be removed.

---

## 💡 Solution

This solution applies fixes in three files to resolve the identified issues.

---

### **File 1: `/src/hooks/use-admin-events.ts`**

#### **Change 1: Add `authClient` Import**
**Instruction**: Add an import for the `authClient` singleton to directly access the most current token state, bypassing potential React state lag.

**Add this line at the top of the file:**
```typescript
import { authClient } from '@/lib/auth-client';
```

---

#### **Change 2: Fix Auth Race Condition on Connection**
**Instruction**: Modify the `connect` function to read the token directly from `authClient` at the moment of connection. This prevents using a stale token from the `useAuth` hook's state, which may not have updated yet after `authClient.init()`.

**In the `useEffect` hook, find the `connect` function and update it:**

**Before**:
```typescript
    const connect = () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
      }

      setStatus('connecting');
      const url = `${API_BASE}/events/sse?token=${token}`;
      console.log('[SSE] Connecting to:', url.replace(token, 'TOKEN'));
      const eventSource = new EventSource(url);
      eventSourceRef.current = eventSource;
```

**After**:
```typescript
    const connect = () => {
      // **Fix**: Directly get the latest token to prevent using a stale one from React state.
      const currentToken = authClient.getAccessToken();
      if (!currentToken) {
        console.log('[SSE] Halting connection: No token available.');
        setStatus('disconnected');
        return;
      }

      if (eventSourceRef.current) {
        eventSourceRef.current.close();
      }

      setStatus('connecting');
      const url = `${API_BASE}/events/sse?token=${currentToken}`;
      console.log('[SSE] Connecting to:', url.replace(currentToken, 'TOKEN'));
      const eventSource = new EventSource(url);
      eventSourceRef.current = eventSource;
```
**Why this fixes it**: The `useAuth` hook's `token` state can be stale during the first render. By calling `authClient.getAccessToken()` right before creating the `EventSource`, we guarantee use of the most up-to-date token, fixing the race condition.

---

#### **Change 3: Handle Token Expiration on Reconnect**
**Instruction**: Update the `onerror` handler to check for a valid token before attempting to reconnect. This prevents infinite reconnection loops if the user's session has expired or they have logged out.

**Find the `eventSource.onerror` handler and update it:**

**Before**:
```typescript
      eventSource.onerror = (err) => {
        console.error('[SSE] Error:', err);
        eventSource.close();
        setStatus('disconnected');

        const delay = Math.min(reconnectDelayRef.current, 30000);
        console.log(`[SSE] Reconnecting in ${delay}ms`);
        reconnectTimeoutRef.current = setTimeout(() => {
          reconnectDelayRef.current = Math.min(delay * 2, 30000);
          connect();
        }, delay);
      };
```

**After**:
```typescript
      eventSource.onerror = (err) => {
        console.error('[SSE] Error:', err);
        eventSource.close();
        setStatus('disconnected');

        // **Fix**: Check for a token before attempting to reconnect.
        const currentToken = authClient.getAccessToken();
        if (!currentToken) {
          console.log('[SSE] Token no longer available, stopping reconnection.');
          if (reconnectTimeoutRef.current) clearTimeout(reconnectTimeoutRef.current);
          return;
        }

        const delay = Math.min(reconnectDelayRef.current, 30000);
        console.log(`[SSE] Reconnecting in ${delay}ms`);
        reconnectTimeoutRef.current = setTimeout(() => {
          reconnectDelayRef.current = Math.min(delay * 2, 30000);
          connect();
        }, delay);
      };
```
**Why this fixes it**: If an SSE error occurs (e.g., network issue or server-side disconnect), this check ensures we only try to reconnect if the user is still authenticated. If the token is gone, it gracefully stops.

---

### **File 2: `/src/components/modals/notification-settings-dialog.tsx`**

#### **Change 4: Make Browser Notification Test Robust**
**Instruction**: Replace the `testBrowserNotification` function with a more robust version that includes `try...catch` error handling, provides clear user feedback via `alert()`, and handles cases where the page is not focused.

**Replace the entire `testBrowserNotification` function:**

**Before**:
```typescript
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
```

**After**:
```typescript
  const testBrowserNotification = () => {
    if (!('Notification' in window)) {
      alert('This browser does not support desktop notifications.');
      return;
    }

    const createNotification = () => {
      try {
        const notification = new Notification('Test Notification', {
          body: 'This is a test notification from Zariz.',
          icon: '/favicon.ico',
        });
        console.log('[Notification] Test notification sent successfully.');
        // Auto-close after 4 seconds for better UX
        setTimeout(() => notification.close(), 4000);

        // If tab is not focused, alert the user that the test was sent.
        if (document.hidden) {
          alert('Test notification sent! Check your system notifications.');
        }
      } catch (error) {
        console.error('[Notification] Failed to create notification:', error);
        alert(`Failed to create notification: ${error instanceof Error ? error.message : String(error)}`);
      }
    };

    if (Notification.permission === 'granted') {
      createNotification();
    } else if (Notification.permission !== 'denied') {
      Notification.requestPermission().then((permission) => {
        if (permission === 'granted') {
          console.log('[Notification] Permission granted.');
          createNotification();
        } else {
          console.log('[Notification] Permission not granted.');
          alert('Notification permission was not granted.');
        }
      });
    } else {
      alert('Notification permission has been denied. You must enable it in your browser settings.');
    }
  };
```
**Why this fixes it**: This version eliminates the silent failure. It provides explicit feedback for every state: unsupported, permission denied, permission granted, and any unexpected errors during creation. It also improves UX by informing the user when a notification was sent to the background.

---

### **File 3: `/src/hooks/use-sse.ts`**

#### **Change 5: Remove Unused File**
**Instruction**: This file is dead code and should be deleted.

**Run this command from the `web-admin-v2` directory:**
```bash
rm src/hooks/use-sse.ts
```
**Why this fixes it**: Removes unnecessary code, reducing codebase size and potential confusion.


---

## ✅ Acceptance Criteria

### SSE Connection
- [ ] Console shows `[SSE] Connecting to: http://localhost:8000/v1/events/sse?token=TOKEN`
- [ ] Network tab shows SSE request with `?token=` parameter (not empty query string)
- [ ] SSE connection returns 200 OK (not 401)
- [ ] Console shows `[SSE] Connected` message
- [ ] No `[SSE] No token available at connection time` errors
- [ ] Connection waits for auth initialization (no premature connection attempts)

### Token Expiration Handling
- [ ] SSE connection stops reconnecting when token becomes invalid
- [ ] Console shows `[SSE] Token no longer available, stopping reconnection` when appropriate
- [ ] No infinite reconnection loops with expired tokens

### Real-time Notifications
- [ ] Create new order → notification appears within 1 second
- [ ] Console shows `[SSE] Message received:` and `[SSE] Parsed event:`
- [ ] Toast notification displays with correct order ID and pickup address
- [ ] Notifications work continuously for >30 minutes (test long-lived connection)

### Browser Notification Test
- [ ] Click "Test" button → see notification or alert message
- [ ] Console shows `[Notification] Test notification sent` or an error message
- [ ] If permission denied → alert explains how to enable
- [ ] If permission granted → notification appears and auto-closes after 3s
- [ ] When tab is not focused → alert confirms notification was sent
- [ ] Error handling works (test by blocking notifications in browser settings)

### Code Cleanup
- [ ] File `/src/hooks/use-sse.ts` is deleted
- [ ] No references to the deleted file remain in the codebase

---

## 🧪 Testing Instructions

### 1. Test SSE Connection
```bash
# 1. Start services
./run.sh start

# 2. Open browser to http://localhost:3002/dashboard/orders
# 3. Open DevTools Console
# 4. Look for [SSE] logs
# 5. Check Network tab for /events/sse request
```

**Expected Console Output**:
```
[SSE] Connecting to: http://localhost:8000/v1/events/sse?token=TOKEN
[SSE] Connected
```

### 2. Test Real-time Notifications
```bash
# 1. Keep browser open on /dashboard/orders
# 2. Create test order via API:
curl -X POST http://localhost:8000/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"store_id": 1, "pickup_address": "Test Address", "delivery_address": "Test Delivery", "boxes_count": 1}'

# 3. Check browser for notification toast
```

### 3. Test Browser Notifications
```bash
# 1. Go to /dashboard/orders
# 2. Click user menu → Notification Settings
# 3. Click "Test" button next to Browser Notifications
```
**Note**: Some browsers prevent notifications if the tab is not in focus. For testing, ensure the tab is visible.

### 4. Verify Token Expiration Handling
```bash
# 1. Start services and login
./run.sh start

# 2. Open browser to http://localhost:3002/dashboard/orders
# 3. Wait for SSE connection to establish
# 4. In another terminal, expire the token in database:
docker exec -it zariz-postgres-1 psql -U zariz -d zariz -c "UPDATE user_sessions SET expires_at = NOW() - INTERVAL '1 hour' WHERE user_id = 1;"

# 5. Wait 30-60 seconds and check console logs
# 6. Should see "Token no longer available, stopping reconnection"
```

### 5. Test Browser Notifications Focus Handling
```bash
# 1. Go to /dashboard/orders
# 2. Click user menu → Notification Settings
# 3. Switch to another tab (make Zariz tab not focused)
# 4. Switch back and click "Test" button
# 5. Should see alert: "Test notification sent! (Check your system notifications)"
```

### 6. Clean Up Dead Code
```bash
# Verify removal of unused SSE hook
rm src/hooks/use-sse.ts
# Verify no references remain
grep -r "use-sse" src/ || echo "No references found - good!"
```

---

## 💡 Potential for further improvement

While the fixes in this ticket will solve the immediate issues, there are opportunities for further code quality improvements:

1. **Auth Hook Refactoring**: The root cause lies in how React state updates interact with closures. A more robust long-term solution would be to refactor the `useAuth` hook to ensure components always get up-to-date tokens without accessing the `authClient` singleton directly.

2. **SSE Reconnection Strategy**: Implement exponential backoff with jitter for reconnection attempts to reduce server load.

3. **Token Refresh Integration**: Add automatic token refresh when SSE connections fail due to expired tokens, rather than just stopping reconnection.

4. **Notification Permission UX**: Add a guide for users to reset notification permissions in browser settings.

5. **Connection Health Monitoring**: Add periodic ping/pong to detect stale connections before they fail.

---

## 🔄 Rollback Plan

If the fix breaks SSE connections:

1. **Revert SSE changes**:
   ```bash
   git checkout HEAD~1 -- src/hooks/use-admin-events.ts
   ```

2. **Revert notification changes** (if needed):
   ```bash
   git checkout HEAD~1 -- src/components/modals/notification-settings-dialog.tsx
   ```

3. **Restore use-sse.ts** (if accidentally needed):
   ```bash
   git checkout HEAD~1 -- src/hooks/use-sse.ts
   ```

4. **Restart development server**:
   ```bash
   ./run.sh restart
   ```

**Alternative approach if main fix fails**: Instead of using `authClient.getAccessToken()` directly, add a `tokenVersion` state to `useAuth` that increments whenever the token changes, and use this as a dependency in `useAdminEvents` to force reconnection with the new token.

```