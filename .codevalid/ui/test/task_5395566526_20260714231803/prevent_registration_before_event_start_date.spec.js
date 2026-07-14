import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupAuthenticatedSession,
  mockProtectedHomePageApis,
  mockRegistrationsApi,
  mockRegistrationSubmit,
} from "../../helpers/mock-api.js";

const formatDate = (date) => date.toISOString().split("T")[0];

test("Prevent attendee registration before event start date", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "prevent_registration_before_event_start_date",
    testName: "Prevent attendee registration before event start date",
  });

  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);
  const dayAfterTomorrow = new Date(today);
  dayAfterTomorrow.setDate(today.getDate() + 2);

  const upcomingEvent = {
    id: "event_upcoming_001",
    title: "Future Launch Day",
    description: "Registration has not opened yet.",
    startDate: formatDate(tomorrow),
    endDate: formatDate(dayAfterTomorrow),
    location: "North Wing",
    registrationCount: 0,
  };

  try {
    await recorder.step("Setup authenticated session with upcoming event mocks");
    await setupAuthenticatedSession(page);
    await mockProtectedHomePageApis(page, { events: [upcomingEvent] });
    await mockRegistrationsApi(page, {
      byEventId: {
        [upcomingEvent.id]: [],
      },
    });
    await mockRegistrationSubmit(page, {
      status: 400,
      responseBody: {
        message: `Registration has not opened yet. Registration opens on ${upcomingEvent.startDate}.`,
      },
    });

    await recorder.step("Open dashboard and inspect event pre-start status");
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "Registration Desk" })).toBeVisible();
    await expect(page.getByText("Registration Upcoming")).toBeVisible();
    await expect(
      page.getByText(`Registration opens on ${upcomingEvent.startDate}.`)
    ).toBeVisible();

    await recorder.step("Assert attendee registration is prevented before event start");
    await expect(page.locator('[name="name"]')).toBeDisabled();
    await expect(page.locator('[name="email"]')).toBeDisabled();
    await expect(page.locator('[name="phone"]')).toBeDisabled();
    await expect(page.getByRole("button", { name: /confirm registration/i })).toBeDisabled();

    console.log("CODEVALID_TEST_ASSERTION_OK:prevent_registration_before_event_start_date");
  } finally {
    await recorder.save(testInfo);
  }
});
