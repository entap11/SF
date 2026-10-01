// Run against the local preview. SF_PLAYWRIGHT_MODULE may point to an existing Playwright install.
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const { chromium } = require(process.env.SF_PLAYWRIGHT_MODULE || "playwright");
const base = process.env.SF_DASHBOARD_URL || "http://127.0.0.1:8766";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(base).hostname))
  throw new Error("Local preview tests require loopback");
const artifacts = path.resolve(
  process.env.SF_DASHBOARD_ARTIFACTS || "/tmp/sf-dashboard-review",
);
const key = "swarmfront.team-console.drafts.v1";
(async () => {
  await fs.mkdir(artifacts, { recursive: true });
  const browser = await chromium.launch({ headless: true, channel: "chrome" });
  try {
    const context = await browser.newContext({
      viewport: { width: 1512, height: 1100 },
      acceptDownloads: true,
    });
    const page = await context.newPage();
    const errors = [],
      foreign = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("request", (r) => {
      if (
        new URL(r.url()).origin !== new URL(base).origin &&
        !r.url().startsWith("blob:")
      )
        foreign.push(r.url());
    });
    await page.goto(base);
    await page.locator("h1").waitFor();
    assert.equal(await page.locator(".stats .stat").count(), 4);
    await page.screenshot({
      path: path.join(artifacts, "overview.png"),
      fullPage: true,
    });
    const getState = () =>
      page.evaluate((k) => JSON.parse(localStorage.getItem(k)), key);
    const navigate = async (name) => {
      await page.locator(`nav a[data-page="${name}"]`).click();
      await page.waitForFunction(
        (n) =>
          location.hash === "#" + n &&
          document.querySelector('nav a[aria-current="page"]')?.dataset.page ===
            n,
        name,
      );
    };
    await navigate("quests");
    assert.equal(await page.locator(".quest-card").count(), 24);
    await page.locator("#quest-search").fill("your own pace");
    assert.equal(await page.locator(".quest-card").count(), 1);
    await page.getByRole("button", { name: "Edit draft →" }).click();
    await page.locator('[name="title"]').fill("Your Own Pace — local draft");
    await page.locator('[name="honey"]').fill("3.25");
    await page.getByRole("button", { name: "Save local draft" }).click();
    assert.equal(
      (await getState()).edits["quest:daily_your_own_pace"].value.reward
        .honey_centi,
      325,
    );
    await page.reload();
    assert.equal(
      (await getState()).edits["quest:daily_your_own_pace"].value.title,
      "Your Own Pace — local draft",
    );
    await page.locator('[data-filter="WEEKLY"]').click();
    assert.equal(await page.locator(".quest-card").count(), 4);
    await navigate("calendar");
    // True browser drag/drop: daily quest lands on the chosen UTC date.
    await page.locator("#calendar-date").fill("2026-10-12");
    await page.locator("#calendar-date").dispatchEvent("change");
    await page
      .locator(".library-card")
      .first()
      .dragTo(page.locator('[data-drop="2026-10-13"]'));
    assert.equal((await getState()).schedule[0].start, "2026-10-13");
    await page
      .locator(".library-card")
      .first()
      .dragTo(page.locator('[data-drop="2026-10-13"]'));
    assert.equal(
      (await getState()).schedule.length,
      1,
      "Duplicate drops must not duplicate assignments",
    );
    const uid = (await getState()).schedule[0].uid;
    await page
      .locator(`[data-move="${uid}"]`)
      .dragTo(page.locator('[data-drop="2026-10-14"]'));
    assert.equal(
      (await getState()).schedule[0].start,
      "2026-10-14",
      "Dragging an event moves its existing identity",
    );
    await page.locator('[data-library="weekly"]').click();
    await page
      .locator(".library-card")
      .first()
      .dragTo(page.locator('[data-drop="2026-10-15"]'));
    assert.equal(
      (await getState()).schedule.find((e) => e.period === "WEEKLY").start,
      "2026-10-12",
    );
    await page.locator('[data-library="contests"]').click();
    await page.locator("#contest-period").selectOption("MONTHLY");
    await page
      .locator(".library-card")
      .first()
      .dragTo(page.locator('[data-drop="2026-10-15"]'));
    assert.equal(
      (await getState()).schedule.find((e) => e.period === "MONTHLY").start,
      "2026-10-01",
    );
    // Add button is the keyboard/touch alternative; daily unsupported periods are disclosed.
    await page.locator("#contest-period").selectOption("DAILY");
    await page
      .locator(".library-card")
      .filter({ hasText: "Time Puzzle · 3 maps" })
      .getByRole("button")
      .click();
    assert.match(
      await page.locator("#editor").innerText(),
      /not supported by the server yet/,
    );
    await page.locator('#plan-form [name="date"]').fill("2026-10-16");
    await page.getByRole("button", { name: "Save local draft" }).click();
    assert.equal((await getState()).schedule.length, 4);
    await page.getByRole("button", { name: "Use quest rotation" }).click();
    const seeded = await getState();
    assert.equal(seeded.schedule.filter((e) => e.kind === "quest").length, 25);
    await page.getByRole("button", { name: "Use quest rotation" }).click();
    assert.equal((await getState()).schedule.length, seeded.schedule.length);
    // Daily slot limit preserves the three-per-day model.
    await page.locator('[data-library="daily"]').click();
    await page.locator("#library-search").fill("Full Session");
    await page
      .locator(".library-card")
      .first()
      .dragTo(page.locator('[data-drop="2026-10-13"]'));
    assert.equal((await getState()).schedule.length, seeded.schedule.length);
    assert.match(
      await page.locator("#toast").innerText(),
      /slots filled|already scheduled/,
    );
    await page.locator('[data-library="contests"]').click();
    await page.locator("#contest-period").selectOption("WEEKLY");
    await page
      .locator(".library-card")
      .first()
      .dragTo(page.locator('[data-drop-period="WEEKLY"]'));
    await page.waitForTimeout(3600);
    await page.screenshot({
      path: path.join(artifacts, "calendar-week.png"),
      fullPage: true,
    });
    await page.locator('[data-view="month"]').click();
    assert.equal(await page.locator(".schedule-day").count(), 42);
    await page.screenshot({
      path: path.join(artifacts, "calendar-month.png"),
      fullPage: true,
    });
    await page.locator('[data-view="day"]').click();
    assert.equal(await page.locator(".schedule-day").count(), 1);
    await navigate("contests");
    assert.equal(await page.locator(".pack-grid .card").count(), 5);
    await page.locator('[data-pack="async-3"]').click();
    const mapId = await page.evaluate(() => SF_CATALOG.maps[4].id);
    await page.locator('[name="map-0"]').selectOption(mapId);
    await page.getByRole("button", { name: "Save local draft" }).click();
    assert.equal(
      (await getState()).edits["contest:async-3"].value.maps[0],
      mapId,
    );
    await page.screenshot({
      path: path.join(artifacts, "contests.png"),
      fullPage: true,
    });
    await navigate("battlepath");
    assert.equal(await page.locator(".level-card").count(), 20);
    await page.locator('[data-track="elite"]').click();
    await page.locator('[data-level="1"]').click();
    await page.locator('[name="quantity"]').fill("9");
    await page.getByRole("button", { name: "Save local draft" }).click();
    assert.equal(
      (await getState()).edits["level:1"].value.tracks.elite.quantity,
      9,
    );
    await page.getByRole("button", { name: "Edit season draft" }).click();
    await page.locator('[name="start"]').fill("2027-01-01");
    await page.locator('[name="end"]').fill("2026-12-01");
    await page.getByRole("button", { name: "Save local draft" }).click();
    assert.match(await page.locator("#form-error").innerText(), /after/);
    await page.getByRole("button", { name: "Cancel", exact: true }).click();
    await page.screenshot({
      path: path.join(artifacts, "battlepath.png"),
      fullPage: true,
    });
    await navigate("drafts");
    const [download] = await Promise.all([
      page.waitForEvent("download"),
      page.getByRole("button", { name: "Export draft bundle ↗" }).click(),
    ]);
    const exportPath = path.join(artifacts, "draft-export.json");
    await download.saveAs(exportPath);
    const exported = JSON.parse(await fs.readFile(exportPath, "utf8"));
    assert.equal(exported.publishable, false);
    assert.equal(exported.schedule.length, (await getState()).schedule.length);
    assert.equal(exported.edits["level:1"].value.tracks.elite.quantity, 9);
    const scheduleBefore = (await getState()).schedule.length;
    await page.locator("[data-remove-event]").first().click();
    assert.equal((await getState()).schedule.length, scheduleBefore - 1);
    await page.locator('[data-discard="quest:daily_your_own_pace"]').click();
    assert.ok(!(await getState()).edits["quest:daily_your_own_pace"]);
    await page.reload();
    assert.equal((await getState()).schedule.length, scheduleBefore - 1);
    await page.setViewportSize({ width: 390, height: 844 });
    await navigate("calendar");
    await page.screenshot({
      path: path.join(artifacts, "calendar-mobile.png"),
      fullPage: true,
    });
    assert.ok(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth + 1,
      ),
      "No horizontal document overflow on mobile",
    );
    const isolated = await browser.newContext();
    const empty = await isolated.newPage();
    await empty.goto(base + "/#drafts");
    assert.match(await empty.locator("main").innerText(), /0 content drafts/);
    assert.equal(
      foreign.length,
      0,
      "Preview must not contact external services",
    );
    assert.deepEqual(errors, []);
    console.log(
      JSON.stringify({
        ok: true,
        smoke: "dev_dashboard_browser",
        checks: [
          "catalog_counts",
          "draft_edit_reload",
          "real_drag_drop",
          "duplicate_prevention",
          "move_identity",
          "weekly_monthly_snap",
          "accessible_add",
          "unsupported_daily_scope_notice",
          "quest_rotation_seed",
          "daily_slot_limit",
          "map_edit",
          "battlepath_edit",
          "season_validation",
          "export",
          "remove_discard",
          "mobile_layout",
          "browser_isolation",
          "no_external_requests",
        ],
        artifacts,
      }),
    );
  } finally {
    await browser.close();
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
