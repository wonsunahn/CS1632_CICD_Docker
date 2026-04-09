import { test, expect } from '@playwright/test';

var baseURL = 'http://localhost:8080';

test('TEST-CONNECTION', async ({ page }) => {
  await page.goto(baseURL);
});