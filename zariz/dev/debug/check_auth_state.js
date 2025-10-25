// Простая проверка состояния авторизации
// Запустите в консоли браузера

console.log('🔍 Checking Auth State...\n');

// 1. localStorage
const storedToken = localStorage.getItem('zariz_access_token');
console.log('1. localStorage token:', storedToken ? `EXISTS (${storedToken.length} chars)` : 'MISSING');

if (storedToken) {
  try {
    const parts = storedToken.split('.');
    const payload = JSON.parse(atob(parts[1]));
    const expired = payload.exp < Date.now() / 1000;
    console.log('   - Expired:', expired);
    console.log('   - Role:', payload.role);
    console.log('   - User ID:', payload.sub);
  } catch (e) {
    console.log('   - Parse error:', e.message);
  }
}

// 2. Check console for [SSE] logs
console.log('\n2. SSE logs - look for [SSE] messages above');

// 3. Check if on dashboard
console.log('\n3. Current page:', window.location.pathname);
console.log('   - On dashboard:', window.location.pathname.includes('/dashboard'));

// 4. Check for React errors
console.log('\n4. Check for React errors or warnings above');

// 5. Network requests
const sseRequests = performance.getEntriesByType('resource')
  .filter(e => e.name.includes('/events/sse'));

console.log('\n5. SSE requests:', sseRequests.length);
sseRequests.forEach((req, i) => {
  console.log(`   ${i + 1}. ${req.name}`);
  console.log(`      - Has token: ${req.name.includes('token=')}`);
});

console.log('\n✅ Done. Now check:');
console.log('   - Are there [SSE] logs showing "Not ready" or "Connecting"?');
console.log('   - Do SSE requests have ?token= in URL?');
console.log('   - Any 401 errors in Network tab?');
