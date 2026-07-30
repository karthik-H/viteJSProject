import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Expired events do not show registration button even if displayed", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_button_disabled_for_expired_events_only",
    testTitle: testInfo.title,
  });

  await recorder.record("Freeze browser date to 2024-06-20 after the event end date");
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
    id: "event_expired_only",
    title: "Past Event",
    description: "Expired event should not allow registration.",
    startDate: "2024-06-10",
    endDate: "2024-06-18",
    location: "Main Hall",
    registrationCount: 0,
  };

  await recorder.record("Mock expired event and empty registrations");
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

  await recorder.record("Verify expired event remains visible but registration is not possible");
  await expect(page.getByText("Past Event", { exact: true })).toBeVisible();
  await expect(page.getByText("Registration Closed", { exact: true })).toBeVisible();
  await expect(page.getByText("Registration closed on 2024-06-18.", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: /Confirm Registration/i })).toBeDisabled();
  await expect(page.locator('[name="name"]')).toBeDisabled();
  await expect(page.locator('[name="email"]')).toBeDisabled();
  await expect(page.locator('[name="phone"]')).toBeDisabled();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_button_disabled_for_expired_events_only");
  await recorder.save(testInfo);
});
