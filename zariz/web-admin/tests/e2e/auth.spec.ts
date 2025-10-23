import { test, expect } from '@playwright/test'

const RUN_E2E = !!process.env.E2E_BACKEND

test.describe('@auth Admin auth flow', () => {
  test.skip(!RUN_E2E, 'Set E2E_BACKEND=1 with running backend to enable')

  test('wrong password shows error', async ({ page }) => {
    await page.goto('/login')
    await page.fill('input[placeholder="Email or phone"]', 'admin@example.com')
    await page.fill('input[placeholder="Password"]', 'wrong')
    await page.click('text=Sign In')
    await expect(page.locator('text=Login failed')).toBeVisible()
  })

  test('admin login success and stays across navigation', async ({ page }) => {
    await page.goto('/login')
    await page.fill('input[placeholder="Email or phone"]', process.env.E2E_ADMIN_ID || '')
    await page.fill('input[placeholder="Password"]', process.env.E2E_ADMIN_PWD || '')
    await page.click('text=Sign In')
    await page.waitForURL('**/orders')
    await page.goto('/orders/new')
    await page.goto('/orders')
  })
})

