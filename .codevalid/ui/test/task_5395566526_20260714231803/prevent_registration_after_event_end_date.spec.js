import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupAuthenticatedSession,
  mockProtectedHomePageApis,
  mockRegistrationsApi,
  mockRegistrationSubmit,
} from "../../helpers/mock-api.js";

const formatDate = (date) => date.toISOString().split("T")[0];

test("Prevent attendee registration after event end date", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "prevent_registration_after_event_end_date",
    testName: "Prevent attendee registration after event end date",
  });

  const today = new Date();
  const twoDaysAgo = new Date(today);
  twoDaysAgo.setDate(today.getDate() - 2);
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);

  const endedEvent = {
    id: "event_closed_001",
    title: "Past Conference",
    description: "Registration period has ended.",
    startDate: formatDate(twoDaysAgo),
    endDate: formatDate(yesterday),
    location: "South Hall",
    registrationCount: 1,
  };

  try {
    await recorder.step("Setup authenticated session with closed event mocks");
    await setupAuthenticatedSession(page);
    await mockProtectedHomePageApis(page, { events: [endedEvent] });
    await mockRegistrationsApi(page, {
      byEventId: {
        [endedEvent.id]: [],
      },
    });
    await mockRegistrationSubmit(page, {
      status: 400,
      responseBody: {
        message: `Registration is closed. The event ended on ${endedEvent.endDate}.`,
      },
    });

    await recorder.step("Open dashboard and inspect event closed status");
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "Registration Desk" })).toBeVisible();
    await expect(page.getByText("Registration Closed")).toBeVisible();
    await expect(page.getByText(`Registration closed on ${endedEvent.endDate}.`)).toBeVisible();

    await recorder.step("Assert attendee registration is prevented after event end");
    await expect(page.locator('[name="name"]')).toBeDisabled();
    await expect(page.locator('[name="email"]')).toBeDisabled();
    await expect(page.locator('[name="phone"]')).toBeDisabled();
    await expect(page.getByRole("button", { name: /confirm registration/i })).toBeDisabled();

    console.log("CODEVALID_TEST_ASSERTION_OK:prevent_registration_after_event_end_date");
  } finally {
    await recorder.save(testInfo);
  }
});
