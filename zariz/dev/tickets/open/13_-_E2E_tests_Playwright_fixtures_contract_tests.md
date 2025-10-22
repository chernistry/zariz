Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md

Title: E2E tests (Playwright), fixtures, contract tests

Objective
- Add Playwright tests for the web panel flows and contract tests for API.

Deliverables
- `zariz/web-admin` Playwright setup and tests for login, create order, view list, realtime update.
- Backend contract tests validating OpenAPI schema and key endpoints.

Reference-driven accelerators (copy/adapt)
- From next-delivery:
  - Reuse component selectors (Button/InputField) for stable Playwright locators.
  - Keep the Next.js dev server startup pattern in CI, mirroring yarn usage.

Playwright
```
cd zariz/web-admin
npm i -D @playwright/test
npx playwright install

cat > tests/orders.spec.ts << 'EOF'
import { test, expect } from '@playwright/test'

test('store can create order and see it listed', async ({ page }) => {
  await page.goto('/login')
  await page.fill('input', 'store@example.com')
  await page.click('text=Sign In')
  await page.goto('/orders/new')
  await page.fill('input[placeholder="Pickup"]', 'A st 1')
  await page.fill('input[placeholder="Delivery"]', 'B st 2')
  await page.click('text=Create Order')
  await page.goto('/orders')
  await expect(page.locator('li').first()).toContainText('#')
})
EOF
```

Contract tests (pytest)
```
def test_openapi_schema(client):
    r = client.get('/openapi.json')
    assert r.status_code == 200
    assert r.json()['info']['title'] == 'Zariz API'
```

Verification
- `npx playwright test` runs and passes against local dev API.

Next
- Observability and docs in Ticket 14.
