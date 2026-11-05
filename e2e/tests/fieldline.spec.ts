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
 * The DOM moves before Flutter has scrolled and redrawn (on a slow machine, by seconds), so each
 * step waits for Flutter's frames, and the target only counts as in view once its box holds still.
 */
async function scrollTo(page: Page, target: ReturnType<Page["locator"]>) {
  const settle = () =>
    page.evaluate(() => new Promise<void>((done) => requestAnimationFrame(() => requestAnimationFrame(() => setTimeout(done, 150)))));
  const box = async () => (await target.count()) ? await target.first().boundingBox() : null;
  const inView = (b: Awaited<ReturnType<typeof box>>) => {
    const height = page.viewportSize()!.height;
    return !!b && b.y > 60 && b.y + b.height < height - 120;
  };
  for (let i = 0; i < 30; i++) {
    await settle();
    const before = await box();
    if (inView(before)) {
      await page.waitForTimeout(250);
      await settle();
      const after = await box();
      if (inView(after) && after!.y === before!.y) break;
      continue;
    }
    await page.evaluate(() => {
      const lists = [...document.querySelectorAll("flt-semantics")].filter(
        (e) => ["scroll", "auto"].includes(getComputedStyle(e).overflowY) && e.scrollHeight > e.clientHeight,
      );
      const list = lists.at(-1);
      if (list) list.scrollTop += 150;
    });
    await page.waitForTimeout(150);
  }
  await expect(target.first()).toBeVisible();
}

/**
 * Clicks [target] until [done] shows. On a slow machine (the CI's Linux WebKit) a click now and
 * then lands while Flutter is still drawing the last frame, and the app never sees it.
 */
async function tapUntil(page: Page, target: ReturnType<Page["locator"]>, done: ReturnType<Page["locator"]>) {
  for (let attempt = 0; attempt < 3; attempt++) {
    if (await done.count()) return;
    await scrollTo(page, target);
    await target.first().click();
    try {
      await expect(done.first()).toBeVisible({ timeout: 8_000 });
      return;
    } catch {
      // Try again.
    }
  }
  await expect(done.first()).toBeVisible();
}

/**
 * Draws a signature on the pad, and draws again if the browser dropped the stroke (WebKit
 * sometimes does while the list settles), until [signed] says the app took it.
 */
async function sign(page: Page, pad: ReturnType<Page["locator"]>, signed: () => Promise<boolean>) {
  for (let attempt = 0; attempt < 4 && !(await signed()); attempt++) {
    await scrollTo(page, pad);
    const b = (await pad.boundingBox())!;
    await page.mouse.move(b.x + 30, b.y + b.height / 2);
    await page.mouse.down();
    for (let i = 1; i <= 12; i++) await page.mouse.move(b.x + 30 + i * 18, b.y + b.height / 2 + (i % 2 ? -14 : 14), { steps: 3 });
    await page.mouse.up();
    await page.waitForTimeout(300);
  }
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
  // A gas appliance: the site safety check comes first.
  for (const label of ["No smell of gas at the appliance", "Carbon monoxide alarm present and working", "Flue and vents clear"]) {
    const box = page.getByRole("checkbox", { name: label });
    await scrollTo(page, box);
    await box.click();
    await expect(box).toBeChecked();
  }
  await tapUntil(page, button(page, "Confirm safety check"), page.getByText(/^Safety check done at /));
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
  const submit = button(page, /^Complete · card \$/);
  await expect(submit).toBeDisabled();

  // The pad is a plain text node in the tree; its box is the drawing area.
  const pad = page.locator("flt-semantics").filter({ hasText: /^Signature pad, (empty|signed)/ }).last();
  await sign(page, pad, () => submit.isEnabled());
  await expect(submit).toBeEnabled();
  // Paid in cash, the exact amount.
  await scrollTo(page, button(page, "Cash"));
  await button(page, "Cash").click();
  await page.getByRole("checkbox", { name: /^Exact \$/ }).click();
  await button(page, /^Complete · cash \$/).click();
  await expect(page.getByRole("heading", { name: "Job completed" })).toBeVisible();
  await expect(text(page, /sent to the customer/)).toBeVisible();
  await expect(page.getByText("Paid in cash")).toBeVisible();
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
  await scrollTo(page, page.getByText(/Everything is synced/));
  await scrollTo(page, page.getByRole("switch", { name: /^Work offline/ }));
  await page.getByRole("switch", { name: /^Work offline/ }).click();
  await tab(page, "Today").click();
  await expect(page.getByText("Offline. Changes are saved on this phone.")).toBeVisible();
  await button(page, "Start travel").click();
  await expect(page.getByText("Offline. 1 change waiting to sync.")).toBeVisible();
  await button(page, "Go online").click();
  // "Syncing" shows for about a second, which a slow browser can miss; the end state is what counts.
  await expect(page.getByText(/Offline|Syncing/)).toHaveCount(0, { timeout: 15_000 });
  const pending = () => page.evaluate(() => (JSON.parse(JSON.parse(localStorage.getItem("flutter.fieldline:state") ?? '""') || "{}").pending ?? []).length);
  await expect.poll(pending).toBe(0);
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
  await button(page, /^Requested\. Mark the restock of Hot surface igniter as received/).click();
  await expect(text(page, /^Hot surface igniter restocked: \d+ in the van\.$/)).toBeVisible();
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
  const dark = page.getByRole("button", { name: "Dark" }).or(page.getByRole("radio", { name: "Dark" })).first();
  await scrollTo(page, dark);
  await dark.click();
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

test("one job at a time, and only on its day", async ({ page }) => {
  await open(page);
  await button(page, "Start travel").click();
  await scrollTo(page, button(page, /^12:30 PM, /));
  await button(page, /^12:30 PM, /).click();
  await expect(button(page, /^Finish NB-\d+ first$/)).toBeDisabled();
  await page.getByRole("button", { name: "Back" }).click();
  await tab(page, "Schedule").click();
  await button(page, /^Fri, Oct 30, \d+ jobs?$/).click();
  await page.getByRole("button", { name: /, Scheduled/ }).first().click();
  await expect(button(page, "Scheduled for Tomorrow")).toBeDisabled();
});

test("office changes made while offline arrive at the next sync, with a conflict to settle", async ({ page }) => {
  await open(page);
  await tab(page, "Profile").click();
  await scrollTo(page, page.getByRole("switch", { name: /^Work offline/ }));
  await page.getByRole("switch", { name: /^Work offline/ }).click();
  await scrollTo(page, button(page, "Simulate"));
  await button(page, "Simulate").click();
  await expect(page.getByText(/3 changes from the office waiting for the next sync/)).toBeVisible();
  await tab(page, "Today").click();
  // Work on the current job while offline: the office cancels that same job.
  await button(page, "Start travel").click();
  // Back to the top of the list, where the sync strip is.
  await page.evaluate(() => document.querySelectorAll("flt-semantics").forEach((e) => (e.scrollTop = 0)));
  await button(page, "Go online").click();
  await expect(page.getByText("Sync conflict")).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText(/The office cancelled NB-\d+ \(customer called: it is working again\) while you were working on it\./)).toBeVisible();
  await expect(page.getByText(/^New urgent job NB-\d+: Burst pipe/)).toBeVisible();
  await expect(page.getByText(/ moved to /)).toBeVisible();
  await button(page, "Stop and cancel the job").click();
  await expect(page.getByText("Sync conflict")).toHaveCount(0);
  await scrollTo(page, button(page, /No heat, .*, Cancelled$/));
  await noSideScroll(page);
});

test("a quote found on site is accepted and booked", async ({ page }) => {
  await open(page);
  await button(page, "Start travel").click();
  await button(page, "Arrived on site").click();
  await button(page, /^No heat Urgent/).click();
  await tapUntil(page, button(page, "New quote"), page.getByRole("heading", { name: "New quote" }));
  await page.getByRole("checkbox", { name: "Igniter and flame sensor upgrade" }).click();
  await expect(page.getByRole("group", { name: /Hot surface igniter kit 1 × \$120\.00/ })).toBeVisible();
  const accept = button(page, /^Accept \$/);
  await expect(accept).toBeDisabled();
  const pad = page.locator("flt-semantics").filter({ hasText: /^Signature pad, (empty|signed)/ }).last();
  await sign(page, pad, () => accept.isEnabled());
  await accept.click();
  await expect(text(page, /^Accepted\. NB-\d+ is booked for /)).toBeVisible();
  // The quote stays on the job, marked accepted with the booked job.
  const quotes = () => page.evaluate(() => JSON.parse(JSON.parse(localStorage.getItem("flutter.fieldline:state") ?? '""') || "{}").quotes ?? []);
  await expect.poll(async () => (await quotes()).map((q: { title: string; status: string }) => `${q.title}: ${q.status}`)).toEqual(["Igniter and flame sensor upgrade: accepted"]);
});

test("running late: customers past their window are texted a new time", async ({ page }) => {
  // 1:30 PM and the 10:30 job not started: the rest of the day runs late.
  await page.clock.install({ time: new Date("2026-10-29T18:30:00Z") });
  await page.goto("./");
  await expect(page.getByRole("heading", { name: "Today" })).toBeVisible({ timeout: 30_000 });
  await expect(page.getByRole("heading", { name: "Running late" })).toBeVisible();
  await button(page, /^Text (the customer|\d+ customers)$/).click();
  await expect(page.getByRole("heading", { name: "Running late" })).toHaveCount(0);
  // The route still shows the new arrival times, marked late.
  await scrollTo(page, button(page, /, arriving around \d+:\d\d (AM|PM), late$/));
  const texts = () => page.evaluate(() => JSON.parse(JSON.parse(localStorage.getItem("flutter.fieldline:state") ?? '""') || "{}").messages ?? []);
  await expect.poll(async () => (await texts()).length).toBeGreaterThan(0);
  expect((await texts())[0].body).toMatch(/I am running late: new arrival around \d+:\d\d (AM|PM) \(your window was /);
});

test("today's hours and takings, with a break", async ({ page }) => {
  await open(page);
  await tab(page, "Profile").click();
  await scrollTo(page, button(page, "Start break"));
  await expect(page.getByRole("group", { name: /^Today's hours Worked .* Since \d+:\d\d (AM|PM)/ })).toBeVisible();
  await expect(page.getByRole("group", { name: /Taken today Card \$[\d,]+ Cash \$[\d,]+ To invoice \$[\d,]+/ })).toBeVisible();
  await button(page, "Start break").click();
  await expect(button(page, "End break")).toBeVisible();
  await expect(page.getByRole("group", { name: /on a break since \d+:\d\d (AM|PM)/ })).toBeVisible();
  await button(page, "End break").click();
  await expect(button(page, "Start break")).toBeVisible();
  await noSideScroll(page);
});
