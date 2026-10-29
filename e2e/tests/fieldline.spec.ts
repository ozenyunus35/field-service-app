import { expect, test, type Page } from "@playwright/test";

// Thursday 29 October 2026, 10:00 in Chicago (the config sets the time zone).
const NOW = new Date("2026-10-29T15:00:00Z");

async function open(page: Page) {
  await page.clock.install({ time: NOW });
  await page.goto("./");
  await expect(page.getByRole("heading", { name: "Today" })).toBeVisible({ timeout: 30_000 });
}

const button = (page: Page, name: string | RegExp) => page.getByRole("button", { name });
// Flutter also announces snackbars in a live region; look only inside the app.
const text = (page: Page, t: string | RegExp) => page.locator("flt-semantics-host").getByText(t);

/**
 * Scrolls the app's list until the target sits well inside the screen, clear of the bottom bars.
 * Flutter turns DOM scrolling of its semantics nodes into scroll actions. Playwright's own
 * scroll-into-view would move the list under the pointer mid-click, so tests scroll first.
 */
async function scrollTo(page: Page, target: ReturnType<Page["locator"]>) {
  const inView = async () => {
    if (!(await target.count())) return false;
    const box = await target.first().boundingBox();
    const height = page.viewportSize()!.height;
    return !!box && box.y > 60 && box.y + box.height < height - 120;
  };
  for (let i = 0; i < 20 && !(await inView()); i++) {
    await page.evaluate(() => {
      const lists = [...document.querySelectorAll("flt-semantics")].filter(
        (e) => ["scroll", "auto"].includes(getComputedStyle(e).overflowY) && e.scrollHeight > e.clientHeight,
      );
      const list = lists.at(-1);
      if (list) list.scrollTop += 150;
    });
    await page.waitForTimeout(300);
  }
  await expect(target.first()).toBeVisible();
}
const tab = (page: Page, name: string | RegExp) => page.getByRole("tab", { name });

async function noSideScroll(page: Page) {
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow).toBeLessThanOrEqual(0);
}

test("opens on today's route with the urgent job next", async ({ page }) => {
  await open(page);
  await expect(page.getByText("Thursday, October 29")).toBeVisible();
  await expect(page.getByText(/2 of 6/)).toBeVisible();
  await expect(button(page, /^No heat Urgent NB-\d+ · /)).toBeVisible();
  await expect(button(page, "Start travel")).toBeVisible();
  await expect(button(page, /^8:00 AM, Furnace tune-up, .*, Completed$/)).toBeVisible();
  await expect(tab(page, /Van stock/)).toBeVisible();
  await noSideScroll(page);
});

test("a technician works a job from travel to signed invoice", async ({ page }) => {
  await open(page);
  await button(page, "Start travel").click();
  await expect(text(page, /was told you are on the way/)).toBeVisible();
  await button(page, "Arrived on site").click();
  await button(page, /^No heat Urgent/).click();

  await expect(page.getByRole("heading", { name: "No heat" })).toBeVisible();
  for (const label of ["Check thermostat and power", "Inspect hot surface igniter", "Check pressure switch and venting", "Confirm a full heating cycle"]) {
    const box = page.getByRole("checkbox", { name: new RegExp(`^${label}`) });
    await scrollTo(page, box);
    await box.click();
    await expect(box).toBeChecked();
  }

  await scrollTo(page, button(page, "Add part"));
  await button(page, "Add part").click();
  await button(page, /^Hot surface igniter/).click();
  await expect(button(page, "Add one Hot surface igniter")).toBeVisible();

  await scrollTo(page, button(page, "Add photo"));
  await button(page, "Add photo").click();
  await expect(text(page, /\b1 photo\b/)).toBeVisible();

  await button(page, "Complete job").click();
  await expect(page.getByText("Customer signature missing")).toBeVisible();
  const submit = button(page, /^Complete and send \$/);
  await expect(submit).toBeDisabled();

  // The pad is a plain text node in the tree; its box is the drawing area.
  const pad = page.locator("flt-semantics").filter({ hasText: /^Signature pad, empty/ }).last();
  await scrollTo(page, pad);
  // Sign, and sign again if the browser dropped the stroke (WebKit sometimes does while the list settles).
  for (let attempt = 0; attempt < 3 && !(await submit.isEnabled()); attempt++) {
    await page.waitForTimeout(300);
    const b = (await pad.boundingBox())!;
    await page.mouse.move(b.x + 30, b.y + b.height / 2);
    await page.mouse.down();
    for (let i = 1; i <= 12; i++) await page.mouse.move(b.x + 30 + i * 18, b.y + b.height / 2 + (i % 2 ? -14 : 14), { steps: 3 });
    await page.mouse.up();
    await page.waitForTimeout(200);
  }
  await expect(submit).toBeEnabled();
  await submit.click();
  await expect(page.getByRole("heading", { name: "Job completed" })).toBeVisible();
  await expect(text(page, /sent to the customer/)).toBeVisible();
  await button(page, "Back to today").click();
  await expect(page.getByText(/3 of 6/)).toBeVisible();
  await scrollTo(page, button(page, /^10:30 AM, No heat, .*, Completed$/));
});

test("progress is kept after a reload", async ({ page }) => {
  await open(page);
  await button(page, "Start travel").click();
  await expect(button(page, "Arrived on site")).toBeVisible();
  await page.reload();
  await expect(button(page, "Arrived on site")).toBeVisible({ timeout: 30_000 });
});

test("offline changes wait and then sync", async ({ page }) => {
  await open(page);
  await tab(page, "Profile").click();
  await expect(page.getByRole("group", { name: /^Everything is synced/ })).toBeVisible();
  await page.getByRole("switch", { name: /^Work offline/ }).click();
  await tab(page, "Today").click();
  await expect(page.getByText("Offline. Changes are saved on this phone.")).toBeVisible();
  await button(page, "Start travel").click();
  await expect(page.getByText("Offline. 1 change waiting to sync.")).toBeVisible();
  await button(page, "Go online").click();
  await expect(page.getByText(/Syncing 1 change/)).toBeVisible();
  await expect(page.getByText(/Offline|Syncing/)).toHaveCount(0, { timeout: 10_000 });
});

test("van stock shows low parts and takes restock requests", async ({ page }) => {
  await open(page);
  await tab(page, /Van stock/).click();
  await expect(page.getByRole("heading", { name: "Van stock" })).toBeVisible();
  await expect(text(page, "Contactor 30A, 1 pole")).toBeVisible();
  await page.getByRole("checkbox", { name: "Low only" }).click();
  await expect(text(page, "Contactor 30A, 1 pole")).toHaveCount(0);
  await button(page, "Request restock of Hot surface igniter").click();
  await expect(text(page, "Restock of Hot surface igniter requested from the warehouse.")).toBeVisible();
  await expect(button(page, "Request restock of Hot surface igniter")).toHaveCount(0);
  await noSideScroll(page);
});

test("schedule shows tomorrow's jobs", async ({ page }) => {
  await open(page);
  await tab(page, "Schedule").click();
  await expect(page.getByRole("heading", { name: "Schedule" })).toBeVisible();
  await button(page, /^Fri, Oct 30, \d+ jobs?$/).click();
  await expect(page.getByText(/^Tomorrow · \d+ jobs? · /)).toBeVisible();
});

test("dark theme and reset", async ({ page }) => {
  await open(page);
  await tab(page, "Profile").click();
  await page.getByRole("button", { name: "Dark" }).or(page.getByRole("radio", { name: "Dark" })).first().click();
  // shared_preferences on the web keeps a JSON-encoded string under "flutter.<key>".
  const theme = () => page.evaluate(() => JSON.parse(JSON.parse(localStorage.getItem("flutter.fieldline:state") ?? '""') || "{}").theme);
  await expect.poll(theme).toBe("dark");

  await scrollTo(page, button(page, "Reset demo data"));
  await button(page, "Reset demo data").click();
  await button(page, /^Reset$/).click();
  await expect(text(page, "Demo data was reset.")).toBeVisible();
});

test("desktop browsers show the app in a phone frame", async ({ page, isMobile }) => {
  test.skip(isMobile, "phones get the app full screen");
  await open(page);
  await expect(text(page, "The technician's day, in one app.")).toBeVisible();
  await expect(button(page, "Source code")).toBeVisible();
});
