import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMockRoutes, teardownMockRoutes } from "../../mock/mock-server.js";

test.describe("Dashboard renders all events with correct registration counts", () => {
  test.beforeEach(async ({ page }) => {
    await setupMockRoutes(page);
  });

  test.afterEach(async ({ page }) => {
    await teardownMockRoutes(page);
  });

  test("dashboard renders all events with correct registration counts", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "dashboard_events_rendered_with_registration_count",
      testTitle: testInfo.title,
    });

    recorder.record("Navigate to home page");
    await page.goto("/");

    recorder.record("Wait for dashboard heading and first event selection to load");
    await expect(page.getByRole("heading", { name: "Registration Desk" })).toBeVisible();
    await expect(page.getByText("Tech Conference 2026")).toBeVisible();

    recorder.record("Verify event selector contains all events from mocked GET /api/events");
    const eventSelector = page.locator("select");
    await expect(eventSelector).toBeVisible();
    await expect(eventSelector.locator('option[value="event_conf2026"]')).toHaveText("Tech Conference 2026");
    await expect(eventSelector.locator('option[value="event_workshop2026"]')).toHaveText("React Workshop");

    recorder.record("Verify selected event date range is rendered for the first event");
    await expect(page.getByText("Event Dates:")).toContainText("2026");

    recorder.record("Verify registration count for initially selected event is reflected in the audience total badge");
    await expect(page.getByText("2 Total")).toBeVisible();
    await expect(page.getByText("Carol Davis")).toBeVisible();
    await expect(page.getByText("Dave Wilson")).toBeVisible();

    recorder.record("Switch to second event and verify its registration count is zero");
    await eventSelector.selectOption("event_workshop2026");
    await expect(page.getByText("0 Total")).toBeVisible();
    await expect(page.getByRole("heading", { name: "No Registered Attendees" })).toBeVisible();

    console.log("CODEVALID_TEST_ASSERTION_OK:dashboard_events_rendered_with_registration_count");
    await recorder.save(testInfo);
  });
});
