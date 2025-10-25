# Ticket 5: Diagnose SSE/Notifications Issues & Create Fix Ticket

**Type:** Investigation → Ticket Creation  
**Priority:** High  
**Estimated Time:** 2-3 hours investigation + ticket writing

---

## 🎯 Objective

Investigate why SSE notifications are failing (401 errors, no real-time updates, browser notifications not working) and create a detailed implementation ticket with root cause analysis and concrete fixes.

---

## 📋 Context

### Original Requirements
See: `/Users/sasha/IdeaProjects/ios/zariz/dev/tickets/open/ticket_4_webadmin_notifications_ui.md`

### Reported Issues
1. Console shows 401 Unauthorized on `/v1/events/sse`
2. New orders don't trigger notifications
3. Browser notification test button does nothing (sound works)

### Available Data
- HAR file: `/Users/sasha/Downloads/affsf.har` (shows 401 errors, empty query strings)
- Debug script: `/Users/sasha/IdeaProjects/ios/zariz/dev/debug/browser_notifications_debug.js`
- Debug results: Token exists in localStorage, manual SSE test succeeds, but actual connections have no token

---

## 🔍 Investigation Tasks

### Phase 1: Reproduce & Verify (30 min)

1. **Run debug script** in browser console on `/dashboard/orders`
2. **Capture fresh HAR file** after page reload
3. **Check console logs** for `[SSE]` messages
4. **Verify localStorage** has `zariz_access_token`
5. **Test manual SSE connection:**
   ```javascript
   const token = localStorage.getItem('zariz_access_token');
   const es = new EventSource(`http://localhost:8000/v1/events/sse?token=${token}`);
   es.onopen = () => console.log('Manual SSE: Connected');
   es.onerror = () => console.log('Manual SSE: Error');
   ```

**Expected Findings:**
- Token exists but not passed to EventSource
- Race condition between auth initialization and SSE connection
- Browser notifications API works but UI issue

### Phase 2: Code Analysis (60 min)

Analyze these files for root cause:

1. **Auth Flow:**
   - `/src/lib/auth-client.ts` - How token is loaded/stored
   - `/src/hooks/use-auth.ts` - How React accesses token
   - Check: Does useAuth initialize with null despite token in localStorage?

2. **SSE Connection:**
   - `/src/hooks/use-admin-events.ts` - How SSE connects
   - Check: Does it wait for `loading: false` before connecting?
   - Check: Is token available when useEffect runs?

3. **Notification UI:**
   - `/src/components/modals/notification-settings-dialog.tsx`
   - Check: Does testBrowserNotification actually create Notification?
   - Check: Are there console errors when clicking test button?

4. **Integration:**
   - `/src/app/dashboard/layout.tsx` or similar - Where useAdminEvents is called
   - Check: Is there duplicate SSE connection somewhere?

**Key Questions to Answer:**
- Why does EventSource URL not include `?token=`?
- Is there a timing issue (token loads after SSE connects)?
- Does useAuth return null initially even when token exists?
- Is NotificationProvider properly integrated?

### Phase 3: Identify Root Causes (30 min)

For each issue, determine:

**Issue 1: SSE 401 Errors**
- [ ] Root cause: _______________
- [ ] Affected files: _______________
- [ ] Minimal fix: _______________

**Issue 2: No Notifications**
- [ ] Root cause: _______________
- [ ] Affected files: _______________
- [ ] Minimal fix: _______________

**Issue 3: Browser Notification Test**
- [ ] Root cause: _______________
- [ ] Affected files: _______________
- [ ] Minimal fix: _______________

### Phase 4: Create Implementation Ticket (30 min)

Write ticket: `/Users/sasha/IdeaProjects/ios/zariz/dev/tickets/open/ticket_6_fix_sse_notifications.md`

**Ticket Must Include:**

1. **Problem Statement** (from Phase 3 findings)
   - Exact root cause for each issue
   - Code snippets showing the problem

2. **Solution** (minimal code changes)
   - File-by-file changes with before/after
   - Why each change fixes the issue
   - No over-engineering

3. **Acceptance Criteria**
   - Specific, testable conditions
   - Console log expectations
   - Network tab verification steps

4. **Testing Instructions**
   - Step-by-step reproduction
   - Expected vs actual behavior
   - How to verify fix works

5. **Rollback Plan**
   - If fix breaks something
   - Alternative approaches

---

## 📊 Deliverables

### 1. Investigation Report
Create: `/Users/sasha/IdeaProjects/ios/zariz/dev/debug/sse_investigation_report.md`

```markdown
# SSE Notifications Investigation Report

## Summary
[One paragraph: what's broken and why]

## Root Causes
1. **SSE 401 Errors:** [Exact cause]
2. **No Notifications:** [Exact cause]  
3. **Browser Test Broken:** [Exact cause]

## Evidence
- HAR analysis: [Key findings]
- Debug script results: [Key findings]
- Code analysis: [Key findings]

## Proposed Fixes
[List minimal changes needed]
```

### 2. Implementation Ticket
Create: `/Users/sasha/IdeaProjects/ios/zariz/dev/tickets/open/ticket_6_fix_sse_notifications.md`

Must follow format:
- Clear problem statement with code examples
- Minimal fixes (no refactoring)
- Concrete acceptance criteria
- Testing steps with expected output

---

## ✅ Acceptance Criteria

This ticket (Ticket 5) is complete when:

- [ ] Investigation report created with root causes identified
- [ ] Ticket 6 created with concrete implementation steps
- [ ] Ticket 6 includes before/after code for each fix
- [ ] Ticket 6 has testable acceptance criteria
- [ ] All findings documented with evidence (HAR, logs, code)
- [ ] Ticket 6 can be handed to any developer to implement

---

## 🎯 Success Metrics

**Good Investigation:**
- Root cause identified in < 2 hours
- Minimal fix proposed (< 10 lines changed)
- Clear reproduction steps

**Good Ticket:**
- Developer can implement without questions
- Acceptance criteria are binary (pass/fail)
- Includes rollback plan

---

## 📝 Notes

### Investigation Approach
1. Start with data (HAR, debug results)
2. Form hypothesis
3. Verify in code
4. Test hypothesis
5. Document findings

### Ticket Writing Principles
- Be specific (file names, line numbers)
- Show code, don't describe it
- One fix per issue
- Minimal changes only
- Test instructions must be copy-pasteable

### Common Pitfalls to Avoid
- Don't propose refactoring
- Don't fix unrelated issues
- Don't add features
- Don't over-engineer
- Focus on minimal fix that works
