import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Dashboard loads and displays all active events with dates and registration counts", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "events_dashboard_loads_active_events",
    testTitle: testInfo.title,
  });

  await recorder.record("Freeze browser date for deterministic event ordering assertions");
  await page.addInitScript(() => {
    const fixed = new Date("2024-06-20T12:00:00.000Z");
    const RealDate = Date;
    class MockDate extends RealDate {
      constructor(...args) {
        if (args.length === 0) {
          super(fixed.toISOString());
        } else {
          super(...args);
        }
      }
      static now() {
        return fixed.getTime();
      }
      static parse(value) {
        return RealDate.parse(value);
      }
      static UTC(...args) {
        return RealDate.UTC(...args);
      }
    }
    window.Date = MockDate;
  });

  await recorder.record("Seed authenticated session");
  await setupAuthenticatedSession(page);

  const events = [
    {
      id: "event_beta",
      title: "Beta Summit",
      description: "Second event by date.",
      startDate: "2024-06-20",
      endDate: "2024-06-22",
      location: "Hall B",
      registrationCount: 3,
    },
    {
      id: "event_alpha",
      title: "Alpha Kickoff",
      description: "First event by date.",
      startDate: "2024-06-15",
      endDate: "2024-06-18",
      location: "Hall A",
      registrationCount: 1,
    },
    {
      id: "event_gamma",
      title: "Gamma Expo",
      description: "Third event by date.",
      startDate: "2024-07-01",
      endDate: "2024-07-02",
      location: "Hall C",
      registrationCount: 0,
    },
  ];

  await recorder.record("Mock GET /api/events with intentionally unsorted payload");
  await page.route("**/api/events", async (route) => {
    const method = route.request().method();
    if (method === "GET") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(events),
      });
      return;
    }
    await route.continue();
  });

  await recorder.record("Load the Events page");
  await page.goto("/events");

  await recorder.record("Verify Events page heading is visible");
  await expect(page.getByRole("heading", { name: "Events Management Setup" })).toBeVisible();

  await recorder.record("Verify all event cards render their titles, dates, and registration counts");
  await expect(page.getByText("Alpha Kickoff", { exact: true })).toBeVisible();
  await expect(page.getByText("2024-06-15 to 2024-06-18", { exact: true })).toBeVisible();
  await expect(page.getByText("1 registered", { exact: true })).toBeVisible();

  await expect(page.getByText("Beta Summit", { exact: true })).toBeVisible();
  await expect(page.getByText("2024-06-20 to 2024-06-22", { exact: true })).toBeVisible();
  await expect(page.getByText("3 registered", { exact: true })).toBeVisible();

  await expect(page.getByText("Gamma Expo", { exact: true })).toBeVisible();
  await expect(page.getByText("2024-07-01 to 2024-07-02", { exact: true })).toBeVisible();
  await expect(page.getByText("0 registered", { exact: true })).toBeVisible();

  await recorder.record("Verify cards are displayed in ascending startDate order");
  const titles = await page.locator("h3.text-lg.font-extrabold").allTextContents();
  expect(titles).toEqual(["Alpha Kickoff", "Beta Summit", "Gamma Expo"]);

  console.log("CODEVALID_TEST_ASSERTION_OK:events_dashboard_loads_active_events");
  await recorder.save(testInfo);
});
