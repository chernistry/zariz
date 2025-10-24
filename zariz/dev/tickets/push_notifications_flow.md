# Push Notifications & Real-time Updates Documentation

## Current Architecture (Development)

### Real-time Updates: SSE (Server-Sent Events)

**Works ONLY when app is in foreground**

```
Backend → SSE stream (/events/sse) → iOS app (foreground) → Local notification
```

**Implementation:**
- `SSEClient.swift` - HTTP connection with `text/event-stream`
- `OrdersSyncManager.swift` - Manages SSE lifecycle
- Connection opens when app enters foreground
- Connection closes when app enters background (iOS limitation)

**Limitations:**
- ❌ Does NOT work when app is closed/background
- ❌ Requires active HTTP connection
- ✅ Works great for web admin (always foreground)
- ✅ Instant updates when app is open

### Background Updates: Polling

**Fallback when SSE is not available**

- Polls every 30 seconds (with jitter) when in foreground
- No updates when app is in background
- See `OrdersSyncManager.tick()`

## Production Architecture (Requires Apple Developer Account)

### APNs Push Notifications

**Works even when app is closed**

```
Backend → Gorush Gateway → APNs → iOS Device → App wakes up → Fetch data
```

**Requirements:**
1. **Apple Developer Account** ($99/year)
2. **APNs Authentication Key** (.p8 file)
3. **App Configuration** (Bundle ID, Team ID, Key ID)

## Why Notifications Don't Work in Background

### Current Behavior:
- ✅ Notifications appear when app is OPEN (via SSE)
- ❌ Notifications DON'T appear when app is CLOSED

### Reason:
iOS **terminates HTTP connections** when app goes to background. SSE is an HTTP connection, so it stops working.

### Solution:
Use **APNs Push Notifications** which work independently of app state.

## How to Enable Real Push Notifications

### Step 1: Get Apple Developer Account
1. Sign up at https://developer.apple.com
2. Pay $99/year membership fee
3. Wait for approval (usually instant)

### Step 2: Create APNs Key
1. Go to https://developer.apple.com/account/resources/authkeys/list
2. Click "+" to create new key
3. Check "Apple Push Notifications service (APNs)"
4. Click "Continue" → "Register"
5. Download `AuthKey_XXXXXXXXXX.p8` file
6. **IMPORTANT**: Save the file, you can only download it once!

### Step 3: Get Required IDs
- **Key ID**: 10 characters, shown after creating key (e.g., `AB12CD34EF`)
- **Team ID**: Account → Membership (e.g., `XYZ1234567`)
- **Bundle ID**: Your iOS app identifier (e.g., `com.zariz.app`)

### Step 4: Configure Backend

```bash
# Copy the key file
cp ~/Downloads/AuthKey_XXXXXXXXXX.p8 /Users/sasha/IdeaProjects/ios/zariz/dev/ops/gorush/keys/AuthKey.p8

# Create .env file
cat > /Users/sasha/IdeaProjects/ios/zariz/.env << EOF
APNS_KEY_ID=AB12CD34EF
APNS_TEAM_ID=XYZ1234567
APNS_TOPIC=com.zariz.app
GORUSH_IOS_MOCK=false
APNS_USE_SANDBOX=1
EOF

# Restart services
./run.sh restart
```

### Step 5: Update gorush.yml

```yaml
ios:
  enabled: true
  key_type: "p8"
  key_path: "/config/AuthKey.p8"
  key_id: "AB12CD34EF"
  team_id: "XYZ1234567"
  topic: "com.zariz.app"
  production: false  # true for production builds
  mock: false        # false for real push
```

### Step 6: Enable in docker-compose.yml

```yaml
backend:
  environment:
    GORUSH_URL: http://gorush:8088/api/push
    GORUSH_TOPIC: com.zariz.app
    GORUSH_SANDBOX: "1"  # "0" for production
```

## Overview
The Zariz system uses APNs (Apple Push Notification service) to deliver real-time notifications to iOS devices about order status changes.

## Architecture

```
Backend API → Gorush Gateway → APNs → iOS App
```

### Components

1. **Backend API** (`backend/app/api/routes/orders.py`)
   - Triggers push notifications on order events
   - Uses `send_silent()` from `backend/app/worker/push.py`

2. **Gorush Gateway** (Optional)
   - Runs on `http://localhost:8088` in development
   - Acts as a proxy to APNs
   - Configured in sandbox/mock mode by default (no Apple credentials needed)

3. **Push Worker** (`backend/app/worker/push.py`)
   - Handles both direct APNs and Gorush routing
   - Sends **silent push notifications** (background, content-available)
   - Priority: 5 (normal)

4. **iOS App**
   - Receives background notifications
   - Fetches updated data when notification arrives

## Push Notification Triggers

### Order Created (Line 205)
```python
send_silent(token, {"type": "order.created", "order_id": o.id})
```
- **When**: New order is created via POST /v1/orders
- **Timing**: Immediate (synchronous with API response)
- **Recipients**: All courier devices with registered tokens

### Order Assigned (Line 311)
```python
send_silent(token, {"type": "order.assigned", "order_id": o.id, "courier_id": courier_id})
```
- **When**: Order is assigned to a courier via POST /v1/orders/{id}/assign
- **Timing**: Immediate
- **Recipients**: Assigned courier's devices

### Order Canceled (Line 340)
```python
send_silent(t, {"type": "order.status_changed", "order_id": o.id, "status": "canceled"})
```
- **When**: Order is canceled via POST /v1/orders/{id}/cancel
- **Timing**: Immediate
- **Recipients**: Assigned courier's devices (if any)

### Order Claimed (Line 412)
```python
send_silent(t, {"type": "order.claimed", "order_id": order_id})
```
- **When**: Courier claims an assigned order via POST /v1/orders/{id}/claim
- **Timing**: Immediate
- **Recipients**: All other courier devices (to remove from their available list)

### Order Status Changed (Line 469)
```python
send_silent(t, {"type": "order.status_changed", "order_id": o.id, "status": o.status})
```
- **When**: Order status is updated via PATCH /v1/orders/{id}
- **Timing**: Immediate
- **Recipients**: Assigned courier's devices

### Order Deleted (Line 497)
```python
send_silent(t, {"type": "order.deleted", "order_id": order_id})
```
- **When**: Order is deleted via DELETE /v1/orders/{id}
- **Timing**: Immediate
- **Recipients**: Assigned courier's devices (if any)

### Assignment Declined (Line 527)
```python
send_silent(t, {"type": "order.assigned_declined", "order_id": o.id})
```
- **When**: Courier declines an assigned order via POST /v1/orders/{id}/decline
- **Timing**: Immediate
- **Recipients**: All courier devices

## Push Type: Silent vs Alert

### Current Implementation: Silent Push
- **Type**: `background` / `content-available`
- **Sound**: None
- **Badge**: 0
- **User Visible**: No (unless app processes and shows local notification)
- **Behavior**: 
  - App wakes up in background
  - Has ~30 seconds to fetch data
  - No user notification unless app creates one

### Why Silent Push?
- Allows app to fetch fresh data before showing notification
- Reduces notification spam
- App can decide whether to show notification based on current state
- Better for frequent updates

## Timing & Latency

### Expected Latency
1. **API → Gorush**: < 100ms (local network)
2. **Gorush → APNs**: 100-500ms (internet)
3. **APNs → Device**: 1-5 seconds (depends on device connectivity)
4. **Total**: ~1-6 seconds under normal conditions

### Delay Factors
- Device network connectivity
- Device power state (Low Power Mode adds delay)
- APNs server load
- Silent push may be delayed if device is idle

## Background Delivery Issue

### Problem
Notifications only arrive when app is in foreground, not when app is closed or in background.

### Possible Causes

1. **Simulator Limitation** ✅ MOST LIKELY
   - iOS Simulator has limited push notification support
   - Background push delivery is unreliable on simulator
   - **Solution**: Test on real device

2. **Missing Background Modes**
   - Check `Info.plist` has `UIBackgroundModes` with `remote-notification`
   - Verify in Xcode: Target → Signing & Capabilities → Background Modes → Remote notifications

3. **APNs Environment Mismatch**
   - Development builds must use sandbox APNs
   - Production builds must use production APNs
   - Check `APNS_USE_SANDBOX` environment variable

4. **Device Token Registration**
   - Verify device token is correctly registered in backend
   - Check token format (64 hex characters, no spaces/brackets)

5. **Push Priority**
   - Current priority: 5 (normal)
   - For immediate delivery, could use priority: 10 (high)
   - Trade-off: High priority drains battery faster

### Recommended Fix

**Step 1**: Test on real device
```bash
# Ensure gorush is configured for sandbox
APNS_USE_SANDBOX=1
GORUSH_SANDBOX=true
```

**Step 2**: Verify iOS app configuration
- Background Modes enabled
- Remote notifications capability
- Proper APNs entitlements

**Step 3**: If still not working, switch to alert push for testing
```python
# In push.py, modify _send_gorush to use alert push
payload = {
    "notifications": [{
        "platform": self._gorush_platform,
        "tokens": [token],
        "topic": self._gorush_topic,
        "production": self._gorush_production,
        "message": "New order available",  # Add message
        "sound": "default",  # Add sound
        "push_type": "alert",  # Change to alert
        "badge": 1,  # Add badge
        "custom": data,
    }]
}
```

## Configuration

### Development (Mock Mode)
```env
GORUSH_URL=http://gorush:8088/api/push
GORUSH_TOPIC=com.zariz.app
GORUSH_SANDBOX=true
APNS_USE_SANDBOX=1
```

### Production (Real APNs)
```env
# Option 1: Via Gorush
GORUSH_URL=http://gorush:8088/api/push
GORUSH_TOPIC=com.zariz.app
GORUSH_SANDBOX=false
APNS_USE_SANDBOX=0

# Option 2: Direct APNs
APNS_KEY_PATH=/path/to/AuthKey.p8
APNS_KEY_ID=XXXXXX
APNS_TEAM_ID=YYYYYY
APNS_TOPIC=com.zariz.app
APNS_USE_SANDBOX=0
```

## Testing

### Test Push Notification
```bash
# Via API (creates order and triggers push)
curl -X POST http://localhost:8000/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "store_id": 1,
    "recipient_first_name": "Test",
    "recipient_last_name": "User",
    "phone": "+1234567890",
    "street": "Test St",
    "building_no": "123",
    "boxes_count": 2,
    "pickup_address": "Store Address",
    "delivery_address": "Customer Address"
  }'
```

### Check Gorush Logs
```bash
docker logs zariz-gorush-1
```

### Check Backend Logs
```bash
docker logs zariz-backend-1 | grep -i push
```

## Troubleshooting

### No notifications received
1. Check device token is registered: `SELECT * FROM devices WHERE user_id = X;`
2. Verify gorush is running: `curl http://localhost:8088/api/stat/app`
3. Check backend logs for push errors
4. Test on real device, not simulator

### Notifications delayed
1. Check device network connectivity
2. Verify APNs priority setting
3. Check device Low Power Mode status
4. Monitor APNs feedback service for invalid tokens

### Notifications only work in foreground
1. **Most likely**: Testing on simulator (use real device)
2. Verify Background Modes capability
3. Check `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` is implemented
4. Ensure app doesn't crash during background fetch

## Future Improvements

1. **Add Alert Push Option**: Allow admin to send visible notifications
2. **Push Analytics**: Track delivery rates and timing
3. **Retry Logic**: Retry failed pushes with exponential backoff
4. **Token Validation**: Remove invalid tokens from database
5. **Priority Tuning**: Use high priority for urgent orders
6. **Rich Notifications**: Add images, actions, and custom UI
