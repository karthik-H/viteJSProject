import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupAuthenticatedSession,
  mockProtectedHomePageApis,
  mockRegistrationsApi,
} from "../../helpers/mock-api.js";

test("Prevent attendee registration before event start date", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "prevent_registration_before_event_start",
    testName: "Prevent attendee registration before event start date",
  });

  const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const nextWeek = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const futureEvent = {
    id: "event_future_001",
    title: "Future Launch Event",
    description: "Registration has not opened yet.",
    startDate: tomorrow,
    endDate: nextWeek,
    location: "Innovation Lab",
    registrationCount: 0,
  };

  try {
    await recorder.step("Set up authenticated session and mocks for an upcoming event");
    await setupAuthenticatedSession(page);
    await mockProtectedHomePageApis(page, { events: [futureEvent] });
    await mockRegistrationsApi(page, {
      byEventId: {
        [futureEvent.id]: [],
      },
    });

    await recorder.step("Open the dashboard home page");
    await page.goto("/");

    await recorder.step("Verify registration is blocked before the event start date");
    await expect(page.getByRole("heading", { name: "Registration Desk" })).toBeVisible();
    await expect(page.getByText("Registration Upcoming")).toBeVisible();
    await expect(page.getByText(`Registration opens on ${tomorrow}.`)).toBeVisible();
    await expect(page.locator('[name="name"]')).toBeDisabled();
    await expect(page.locator('[name="email"]')).toBeDisabled();
    await expect(page.locator('[name="phone"]')).toBeDisabled();
    await expect(page.getByRole("button", { name: /confirm registration/i })).toBeDisabled();

    console.log("CODEVALID_TEST_ASSERTION_OK:prevent_registration_before_event_start");
  } finally {
    await recorder.save(testInfo);
  }
});
