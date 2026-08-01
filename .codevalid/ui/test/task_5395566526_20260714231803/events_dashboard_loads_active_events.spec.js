import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMockRoutes, teardownMockRoutes } from "../../mock/mock-server.js";

const AUTH_KEY = "auth";

async function freezeDate(page, isoDate) {
  const frozenIso = `${isoDate}T12:00:00.000Z`;
  await page.addInitScript(({ now }) => {
    const RealDate = Date;
    class MockDate extends RealDate {
      constructor(...args) {
        if (args.length === 0) {
          super(now);
        } else {
          super(...args);
        }
      }
      static now() {
        return new RealDate(now).getTime();
      }
      static parse(value) {
        return RealDate.parse(value);
      }
      static UTC(...args) {
        return RealDate.UTC(...args);
      }
    }
    Object.setPrototypeOf(MockDate, RealDate);
    // eslint-disable-next-line no-global-assign
    Date = MockDate;
  }, { now: frozenIso });
}

async function setupAuthenticatedSession(page) {
  await page.addInitScript((storageKey) => {
    window.localStorage.setItem(
      storageKey,
      JSON.stringify({
        token: "mock-jwt-token",
        user: { id: "user_alice001", email: "alice@example.com", fullName: "Alice Johnson" }
      })
    );
  }, AUTH_KEY);
}

test("Dashboard loads and displays all active events with dates and registration counts", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "events_dashboard_loads_active_events",
    testTitle: testInfo.title,
  });

  await freezeDate(page, "2024-06-20");
  await setupAuthenticatedSession(page);
  await setupMockRoutes(page);

  try {
    recorder.record("Navigate to the Events dashboard");
    await page.goto("/events");

    recorder.record("Verify Events Management Setup heading is visible");
    await expect(page.getByRole("heading", { name: "Events Management Setup" })).toBeVisible();

    recorder.record("Verify seeded events are rendered in ascending start-date order with dates and registration counts");
    const eventTitles = page.locator("h3.text-lg.font-extrabold");
    await expect(eventTitles).toHaveCount(2);
    await expect(eventTitles.nth(0)).toHaveText("Tech Conference 2026");
    await expect(eventTitles.nth(1)).toHaveText("React Workshop");

    await expect(page.getByText("Tech Conference 2026")).toBeVisible();
    await expect(page.getByText("React Workshop")).toBeVisible();
    await expect(page.getByText("2024-06-20 to 2024-07-20")).toBeVisible();
    await expect(page.getByText("2024-07-20 to 2024-08-19")).toBeVisible();
    await expect(page.getByText("2 registered")).toBeVisible();
    await expect(page.getByText("0 registered")).toBeVisible();

    console.log("CODEVALID_TEST_ASSERTION_OK:events_dashboard_loads_active_events");
    await recorder.save(testInfo);
  } finally {
    await teardownMockRoutes(page);
  }
});
