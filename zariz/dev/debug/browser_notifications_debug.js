// ============================================
// ZARIZ NOTIFICATIONS DEBUG SCRIPT
// ============================================
// Запустите в консоли браузера на странице dashboard
// Скопирует результаты в буфер обмена автоматически

(async function debugNotifications() {
  const results = {
    timestamp: new Date().toISOString(),
    url: window.location.href,
    checks: {}
  };

  console.log('🔍 Starting Zariz Notifications Debug...\n');

  // ============================================
  // 1. AUTH CHECK
  // ============================================
  console.log('1️⃣ Checking Authentication...');
  results.checks.auth = {};

  try {
    // Check localStorage token
    const storedToken = localStorage.getItem('zariz_access_token');
    results.checks.auth.localStorage = {
      tokenExists: !!storedToken,
      tokenLength: storedToken ? storedToken.length : 0,
      tokenPreview: storedToken ? storedToken.substring(0, 20) + '...' : 'NONE'
    };
    
    // Check if token is valid JWT
    if (storedToken) {
      try {
        const parts = storedToken.split('.');
        results.checks.auth.localStorage.isJWT = parts.length === 3;
        if (parts.length === 3) {
          const payload = JSON.parse(atob(parts[1]));
          results.checks.auth.localStorage.payload = {
            exp: payload.exp,
            expired: payload.exp ? Date.now() / 1000 > payload.exp : 'unknown',
            role: payload.role || payload.user_type,
            userId: payload.sub || payload.user_id
          };
        }
      } catch (e) {
        results.checks.auth.localStorage.jwtParseError = e.message;
      }
    }

    // Check React state (useAuth hook)
    // Try to access window.__REACT_DEVTOOLS_GLOBAL_HOOK__ or check DOM
    results.checks.auth.reactState = {
      note: 'Check React DevTools or console logs for useAuth state'
    };

    // Check if user is on authenticated page
    results.checks.auth.onAuthPage = window.location.pathname.includes('/dashboard');
    
    // Check cookies
    const cookies = document.cookie.split(';').map(c => c.trim());
    const authCookies = cookies.filter(c => c.includes('auth') || c.includes('token') || c.includes('session'));
    results.checks.auth.cookies = authCookies.length > 0 ? authCookies : 'none';

  } catch (e) {
    results.checks.auth.error = e.message;
  }

  console.log('✅ Auth check complete\n');

  // ============================================
  // 2. SSE CONNECTION CHECK
  // ============================================
  console.log('2️⃣ Checking SSE Connection...');
  results.checks.sse = {
    activeConnections: [],
    eventSourceSupport: typeof EventSource !== 'undefined'
  };

  // Check for active EventSource connections
  if (typeof EventSource !== 'undefined') {
    // Try to find EventSource instances in window
    const checkSSE = () => {
      const connections = [];
      try {
        // Check if there's an active connection by looking at network
        const perfEntries = performance.getEntriesByType('resource');
        const sseRequests = perfEntries.filter(e => 
          e.name.includes('/events/sse') || e.name.includes('/v1/events')
        );
        
        sseRequests.forEach(req => {
          connections.push({
            url: req.name,
            duration: req.duration,
            startTime: req.startTime,
            hasToken: req.name.includes('token=')
          });
        });
      } catch (e) {
        results.checks.sse.perfError = e.message;
      }
      return connections;
    };

    results.checks.sse.activeConnections = checkSSE();
    results.checks.sse.connectionCount = results.checks.sse.activeConnections.length;
  }

  console.log('✅ SSE check complete\n');

  // ============================================
  // 3. BROWSER NOTIFICATIONS CHECK
  // ============================================
  console.log('3️⃣ Checking Browser Notifications...');
  results.checks.browserNotifications = {};

  if ('Notification' in window) {
    results.checks.browserNotifications.supported = true;
    results.checks.browserNotifications.permission = Notification.permission;
    
    // Check if permission can be requested
    if (Notification.permission === 'default') {
      results.checks.browserNotifications.canRequest = true;
      console.log('⚠️  Browser notification permission not requested yet');
    } else if (Notification.permission === 'denied') {
      results.checks.browserNotifications.warning = 'Permission DENIED - must enable in browser settings';
      console.log('❌ Browser notifications DENIED');
    } else {
      console.log('✅ Browser notifications GRANTED');
    }

    // Test notification creation
    if (Notification.permission === 'granted') {
      try {
        const testNotif = new Notification('Debug Test', {
          body: 'If you see this, browser notifications work',
          tag: 'debug-test',
          requireInteraction: false
        });
        setTimeout(() => testNotif.close(), 3000);
        results.checks.browserNotifications.testSent = true;
      } catch (e) {
        results.checks.browserNotifications.testError = e.message;
      }
    }
  } else {
    results.checks.browserNotifications.supported = false;
    console.log('❌ Browser notifications NOT supported');
  }

  console.log('✅ Browser notifications check complete\n');

  // ============================================
  // 4. NOTIFICATION SETTINGS CHECK
  // ============================================
  console.log('4️⃣ Checking Notification Settings...');
  results.checks.settings = {
    soundEnabled: localStorage.getItem('notifications_sound') === 'true',
    browserEnabled: localStorage.getItem('notifications_browser') === 'true'
  };

  console.log('✅ Settings check complete\n');

  // ============================================
  // 5. AUDIO CHECK
  // ============================================
  console.log('5️⃣ Checking Audio...');
  results.checks.audio = {};

  try {
    const audio = new Audio('/sounds/notification.wav');
    results.checks.audio.canCreateAudio = true;
    
    // Try to load
    audio.addEventListener('loadeddata', () => {
      results.checks.audio.audioLoaded = true;
      results.checks.audio.duration = audio.duration;
    });
    
    audio.addEventListener('error', (e) => {
      results.checks.audio.loadError = e.message || 'Failed to load audio file';
    });

    // Check if file exists
    fetch('/sounds/notification.wav', { method: 'HEAD' })
      .then(res => {
        results.checks.audio.fileExists = res.ok;
        results.checks.audio.fileStatus = res.status;
      })
      .catch(e => {
        results.checks.audio.fetchError = e.message;
      });

  } catch (e) {
    results.checks.audio.error = e.message;
  }

  console.log('✅ Audio check complete\n');

  // ============================================
  // 6. NETWORK CHECK
  // ============================================
  console.log('6️⃣ Checking Network Requests...');
  results.checks.network = {};

  try {
    const perfEntries = performance.getEntriesByType('resource');
    
    // Check SSE requests
    const sseRequests = perfEntries.filter(e => 
      e.name.includes('/events/sse') || e.name.includes('/v1/events')
    );
    
    results.checks.network.sseRequests = sseRequests.map(r => ({
      url: r.name,
      duration: r.duration,
      transferSize: r.transferSize,
      hasToken: r.name.includes('token=')
    }));

    // Check API base
    const apiCalls = perfEntries.filter(e => 
      e.name.includes('localhost:8000') || e.name.includes('/v1/')
    );
    
    results.checks.network.apiCallsCount = apiCalls.length;
    results.checks.network.recentAPICalls = apiCalls.slice(-5).map(r => ({
      url: r.name,
      duration: r.duration
    }));

  } catch (e) {
    results.checks.network.error = e.message;
  }

  console.log('✅ Network check complete\n');

  // ============================================
  // 7. REACT STATE CHECK
  // ============================================
  console.log('7️⃣ Checking React State...');
  results.checks.react = {};

  try {
    // Try to find React root
    const root = document.getElementById('__next') || document.getElementById('root');
    if (root) {
      results.checks.react.rootFound = true;
      
      // Check for React DevTools
      results.checks.react.hasReactDevTools = !!window.__REACT_DEVTOOLS_GLOBAL_HOOK__;
      
      // Try to find fiber
      const fiberKey = Object.keys(root).find(key => key.startsWith('__reactFiber'));
      results.checks.react.hasFiber = !!fiberKey;
    }
  } catch (e) {
    results.checks.react.error = e.message;
  }

  console.log('✅ React check complete\n');

  // ============================================
  // 8. CONSOLE ERRORS CHECK
  // ============================================
  console.log('8️⃣ Checking Console Errors...');
  results.checks.consoleErrors = {
    note: 'Check browser console for 401, CORS, or SSE errors manually'
  };

  // ============================================
  // 9. LIVE SSE TEST
  // ============================================
  console.log('9️⃣ Testing Live SSE Connection...');
  results.checks.liveSSETest = {};

  const token = localStorage.getItem('zariz_access_token');
  if (token) {
    const testSSE = new Promise((resolve) => {
      const timeout = setTimeout(() => {
        resolve({ status: 'timeout', message: 'Connection timeout after 5s' });
      }, 5000);

      try {
        const url = `http://localhost:8000/v1/events/sse?token=${token}`;
        const es = new EventSource(url);
        
        es.onopen = () => {
          clearTimeout(timeout);
          es.close();
          resolve({ status: 'success', message: 'Connection opened successfully' });
        };
        
        es.onerror = (e) => {
          clearTimeout(timeout);
          es.close();
          resolve({ 
            status: 'error', 
            message: 'Connection failed',
            readyState: es.readyState 
          });
        };
      } catch (e) {
        clearTimeout(timeout);
        resolve({ status: 'exception', message: e.message });
      }
    });

    results.checks.liveSSETest = await testSSE;
  } else {
    results.checks.liveSSETest = { status: 'skipped', message: 'No auth token' };
  }

  console.log('✅ Live SSE test complete\n');

  // ============================================
  // SUMMARY
  // ============================================
  console.log('📊 SUMMARY\n');
  console.log('='.repeat(50));

  const issues = [];

  if (!results.checks.auth.tokenExists) {
    issues.push('❌ NO AUTH TOKEN - User not logged in');
  } else if (results.checks.auth.tokenPayload?.expired) {
    issues.push('❌ AUTH TOKEN EXPIRED');
  }

  if (results.checks.sse.connectionCount === 0) {
    issues.push('❌ NO SSE CONNECTIONS FOUND');
  } else if (!results.checks.sse.activeConnections.some(c => c.hasToken)) {
    issues.push('❌ SSE CONNECTIONS WITHOUT TOKEN');
  }

  if (results.checks.browserNotifications.permission === 'denied') {
    issues.push('⚠️  Browser notifications DENIED');
  } else if (results.checks.browserNotifications.permission === 'default') {
    issues.push('⚠️  Browser notifications NOT REQUESTED');
  }

  if (!results.checks.settings.soundEnabled) {
    issues.push('ℹ️  Sound notifications DISABLED in settings');
  }

  if (!results.checks.settings.browserEnabled) {
    issues.push('ℹ️  Browser notifications DISABLED in settings');
  }

  if (results.checks.liveSSETest.status !== 'success') {
    issues.push(`❌ LIVE SSE TEST FAILED: ${results.checks.liveSSETest.message}`);
  }

  if (issues.length === 0) {
    console.log('✅ NO ISSUES DETECTED');
  } else {
    console.log('ISSUES FOUND:\n');
    issues.forEach(issue => console.log(issue));
  }

  console.log('\n' + '='.repeat(50));
  console.log('\n📋 Full results copied to clipboard!');
  console.log('Paste them in your response to Q\n');
  
  console.log('🔍 MANUAL CHECKS:');
  console.log('1. Look for [SSE] logs in console above');
  console.log('2. Check Network tab for /events/sse requests');
  console.log('3. Verify you see "Orders" page content (not login page)');
  console.log('4. Run: localStorage.getItem("zariz_access_token")');
  console.log('');

  // Copy to clipboard
  const output = JSON.stringify(results, null, 2);
  try {
    await navigator.clipboard.writeText(output);
    console.log('✅ Results copied to clipboard successfully');
  } catch (e) {
    console.log('⚠️  Could not copy to clipboard automatically');
    console.log('Copy the output below:\n');
    console.log(output);
  }

  return results;
})();
