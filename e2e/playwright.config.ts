import { defineConfig, devices } from "@playwright/test";

// Against the live site: BASE_URL=https://ozenyunus35.github.io/field-service-app/ npx playwright test
const live = process.env.BASE_URL;

export default defineConfig({
  testDir: "tests",
  fullyParallel: true,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? "github" : "list",
  timeout: 60_000,
  expect: { timeout: 10_000 },
  use: {
    baseURL: live ?? "http://localhost:4174/field-service-app/",
    timezoneId: "America/Chicago",
    trace: "retain-on-failure",
  },
  projects: [
    { name: "desktop-chrome", use: { ...devices["Desktop Chrome"] } },
    { name: "desktop-safari", use: { ...devices["Desktop Safari"] } },
    { name: "iphone", use: { ...devices["iPhone 15"] } },
    { name: "android", use: { ...devices["Pixel 7"] } },
  ],
  webServer: live
    ? undefined
    : { command: "node serve.mjs", url: "http://localhost:4174/field-service-app/", reuseExistingServer: !process.env.CI },
});
