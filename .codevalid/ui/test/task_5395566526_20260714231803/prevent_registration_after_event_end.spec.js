import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupAuthenticatedSession,
  mockProtectedHomePageApis,
  mockRegistrationsApi,
} from "../../helpers/mock-api.js";

test("Prevent attendee registration after event end date", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "prevent_registration_after_event_end",
    testName: "Prevent attendee registration after event end date",
  });

  const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const endedEvent = {
    id: "event_past_001",
    title: "Completed Workshop",
    description: "This event has already ended.",
    startDate: twoDaysAgo,
    endDate: yesterday,
    location: "Conference Room B",
    registrationCount: 0,
  };

  try {
    await recorder.step("Set up authenticated session and mocks for a completed event");
    await setupAuthenticatedSession(page);
    await mockProtectedHomePageApis(page, { events: [endedEvent] });
    await mockRegistrationsApi(page, {
      byEventId: {
        [endedEvent.id]: [],
      },
    });

    await recorder.step("Open the dashboard home page");
    await page.goto("/");

    await recorder.step("Verify registration is blocked after the event end date");
    await expect(page.getByRole("heading", { name: "Registration Desk" })).toBeVisible();
    await expect(page.getByText("Registration Closed")).toBeVisible();
    await expect(page.getByText(`Registration closed on ${yesterday}.`)).toBeVisible();
    await expect(page.locator('[name="name"]')).toBeDisabled();
    await expect(page.locator('[name="email"]')).toBeDisabled();
    await expect(page.locator('[name="phone"]')).toBeDisabled();
    await expect(page.getByRole("button", { name: /confirm registration/i })).toBeDisabled();

    console.log("CODEVALID_TEST_ASSERTION_OK:prevent_registration_after_event_end");
  } finally {
    await recorder.save(testInfo);
  }
});
