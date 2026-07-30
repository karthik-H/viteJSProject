import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Registration button is disabled when current date is before event start date", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_button_disabled_before_start_date",
    testTitle: testInfo.title,
  });

  await recorder.record("Freeze browser date to 2024-06-20");
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
    id: "event_future_window",
    title: "Future Registration Event",
    description: "Registration should not yet be open.",
    startDate: "2024-06-25",
    endDate: "2024-07-05",
    location: "Main Hall",
    registrationCount: 0,
  };

  await recorder.record("Mock future event and empty registrations");
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

  await recorder.record("Verify upcoming registration messaging and disabled form state");
  await expect(page.getByText("Registration Upcoming", { exact: true })).toBeVisible();
  await expect(page.getByText("Registration opens on 2024-06-25.", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: /Confirm Registration/i })).toBeDisabled();
  await expect(page.locator('[name="name"]')).toBeDisabled();
  await expect(page.locator('[name="email"]')).toBeDisabled();
  await expect(page.locator('[name="phone"]')).toBeDisabled();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_button_disabled_before_start_date");
  await recorder.save(testInfo);
});
