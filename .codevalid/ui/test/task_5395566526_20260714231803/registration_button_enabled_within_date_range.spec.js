import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Registration button is enabled when current date is within event start and end dates", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_button_enabled_within_date_range",
    testTitle: testInfo.title,
  });

  await recorder.record("Freeze browser date to 2024-06-20");
  await page.addInitScript(() => {
    const fixed = new Date("2024-06-20T12:00:00.000Z");
    const RealDate = Date;
    class MockDate extends RealDate {
      constructor(...args) {
        super(args.length === 0 ? fixed.toISOString() : ...args);
      }
      static now() { return fixed.getTime(); }
      static parse(value) { return RealDate.parse(value); }
      static UTC(...args) { return RealDate.UTC(...args); }
    }
    window.Date = MockDate;
  });

  await recorder.record("Seed authenticated session");
  await setupAuthenticatedSession(page);

  const event = {
    id: "event_open_window",
    title: "Open Registration Event",
    description: "Registration should be active.",
    startDate: "2024-06-15",
    endDate: "2024-06-25",
    location: "Main Hall",
    registrationCount: 0,
  };

  await recorder.record("Mock dashboard event and empty registrations");
  await page.route("**/api/events", async (route) => {
    if (route.request().method() === "GET") {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([event]) });
      return;
    }
    await route.continue();
  });
  await page.route("**/api/registrations/*", async (route) => {
    if (route.request().method() === "GET") {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([]) });
      return;
    }
    await route.continue();
  });

  await recorder.record("Open registration dashboard");
  await page.goto("/");

  await recorder.record("Verify registration status is active and submit button is enabled");
  await expect(page.getByText("You can register attendees for this event.", { exact: true })).toBeVisible();
  await expect(page.getByText("Registration Active", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: /Confirm Registration/i })).toBeEnabled();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_button_enabled_within_date_range");
  await recorder.save(testInfo);
});
