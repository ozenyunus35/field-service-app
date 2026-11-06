import { expect, test } from "@playwright/test";

const NOW = new Date("2026-10-29T15:00:00Z");

test("a ?lang=tr link opens the app in Turkish and the choice is kept", async ({ page }) => {
  await page.clock.install({ time: NOW });
  await page.goto("./?lang=tr");
  await expect(page.getByRole("heading", { name: "Bugün" })).toBeVisible({ timeout: 30_000 });
  await expect(page.locator("flt-semantics-host").getByText("Rota").first()).toBeVisible();
  // 24-hour times in Turkish.
  await expect(page.locator("flt-semantics-host").getByText(/\b\d{2}:\d{2}\b/).first()).toBeVisible();
  await page.goto("./");
  await expect(page.getByRole("heading", { name: "Bugün" })).toBeVisible({ timeout: 30_000 });
});
