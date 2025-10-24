import { test, expect } from '@playwright/test'

test('store can create order and see it listed', async ({ page }) => {
  await page.goto('/login')
  await page.fill('input', '1') // subject
  await page.click('text=Sign In')
  await page.goto('/orders/new')
  await page.fill('input[placeholder="Pickup address"]', 'A st 1')
  await page.fill('input[placeholder="Delivery address"]', 'B st 2')
  await page.click('text=Create Order')
  await page.goto('/orders')
  await expect(page.locator('li').first()).toContainText('#')
})

