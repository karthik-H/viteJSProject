import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Registration button is enabled exactly on event end date", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_button_enabled_on_end_date",
    testTitle: testInfo.title,
  });

  await recorder.record("Freeze browser date to event end date 2024-06-20");
  await page.addInitScript(() => {
    const fixed = new Date("2024-06-20T12:00:00.000Z");
    const RealDate = Date;
    class MockDate extends RealDate {
      constructor(...args) { super(args.length === 0 ? fixed.toISOString() : ...args); }
      static now() { return fixed.getTime(); }
      static parse(value) { return RealDate.parse(value); }
      static UTC(...args) { return RealDate.UTC(...args); }
    }
    window.Date = MockDate;
  });

  await recorder.record("Seed authenticated session");
  await setupAuthenticatedSession(page);

  const event = {
    id: "event_end_boundary",
    title: "End Boundary Event",
    description: "Registration closes after today.",
    startDate: "2024-06-01",
    endDate: "2024-06-20",
    location: "Main Hall",
    registrationCount: 0,
  };

  await recorder.record("Mock boundary event and registrations");
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

  await recorder.record("Assert registration is active exactly on the end date");
  await expect(page.getByText("Registration Active", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: /Confirm Registration/i })).toBeEnabled();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_button_enabled_on_end_date");
  await recorder.save(testInfo);
});
