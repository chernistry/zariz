# SSE Notifications Investigation Report

## Summary
SSE notifications are failing due to 401 Unauthorized errors when connecting to `/v1/events/sse`. The EventSource connections are being made without authentication tokens, preventing real-time order notifications from working. Browser notification tests also fail silently.

## Root Causes

### 1. SSE 401 Errors
**Exact cause**: EventSource connections to `/v1/events/sse` are made without authentication tokens in the query string.

**Evidence from HAR analysis**:
- URL: `http://localhost:8000/v1/events/sse` 
- Query string: `[]` (empty)
- Response: `401 Unauthorized`
- No Authorization header present

**Code analysis**: In `use-admin-events.ts`, the URL construction looks correct:
```typescript
const url = `${API_BASE}/events/sse?token=${token}`;
```

**Potential causes**:
- Race condition: SSE connects before `token` is available
- Token becomes null/undefined after initial auth check
- Auth state not properly synchronized with SSE hook

### 2. No Notifications
**Exact cause**: Consequence of SSE 401 errors - no events are received because the connection fails.

**Evidence**: 
- Console shows `[SSE] Error:` messages
- No `[SSE] Message received:` logs
- New orders don't trigger notifications

### 3. Browser Notification Test Broken  
**Exact cause**: Unknown - code appears correct but test button produces no visible result.

**Code analysis**: The `testBrowserNotification` function in `notification-settings-dialog.tsx` looks correct:
```typescript
const testBrowserNotification = () => {
  if (!('Notification' in window)) {
    alert('Browser notifications not supported');
    return;
  }
  // ... proper permission handling and notification creation
};
```

**Potential causes**:
- Permission already denied (no alert shown)
- Notification created but not visible due to browser settings
- JavaScript error preventing execution
- Focus/visibility requirements not met

## Evidence

### HAR Analysis
- Multiple requests to `/v1/events/sse` with empty query strings
- All requests return 401 Unauthorized
- No token parameter in any SSE request URLs

### Debug Script Results
- Token exists in localStorage: `zariz_access_token`
- Manual SSE test with token succeeds
- Actual SSE connections have no token parameter

### Code Analysis
- `use-admin-events.ts` has proper auth checks: `if (loading || !isAuthenticated || !token)`
- `use-sse.ts` exists but is unused (confirmed via grep)
- Only one EventSource creation point in `use-admin-events.ts`
- Auth client properly loads token from localStorage

## Proposed Fixes

### Fix 1: SSE Authentication Race Condition
**Problem**: Token might be null when SSE connection is established
**Solution**: Add additional token validation and logging

### Fix 2: Browser Notification Test
**Problem**: Test button doesn't show visible result
**Solution**: Add error handling and user feedback

### Fix 3: Enhanced Debugging
**Problem**: Insufficient logging to diagnose auth timing issues
**Solution**: Add detailed console logging for auth state changes

## Next Steps
Create implementation ticket with minimal code changes to fix these issues without over-engineering.
