import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupAuthenticatedSession,
  mockProtectedHomePageApis,
  mockRegistrationsApi,
} from "../../helpers/mock-api.js";

const formatDate = (date) => date.toISOString().split("T")[0];

test("Display active events on the dashboard", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "events_dashboard_displays_active_events",
    testName: "Display active events on the dashboard",
  });

  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);

  const activeEvent = {
    id: "event_active_dashboard",
    title: "CodeValid Summit",
    description: "Current active event for attendee intake.",
    startDate: formatDate(yesterday),
    endDate: formatDate(tomorrow),
    location: "Main Hall",
    registrationCount: 3,
  };

  try {
    await recorder.step("Setup authenticated session and dashboard API mocks");
    await setupAuthenticatedSession(page);
    await mockProtectedHomePageApis(page, { events: [activeEvent] });
    await mockRegistrationsApi(page, {
      byEventId: {
        [activeEvent.id]: [],
      },
    });

    await recorder.step("Open the dashboard home route");
    await page.goto("/");

    await recorder.step("Assert active event details and registration availability are visible");
    await expect(page).toHaveURL(/\/$/);
    await expect(page.getByRole("heading", { name: "Registration Desk" })).toBeVisible();
    await expect(page.getByText("Select Active Event")).toBeVisible();
    await expect(page.locator("select")).toContainText(activeEvent.title);
    await expect(page.getByText("Registration Active")).toBeVisible();
    await expect(page.getByText("You can register attendees for this event.")).toBeVisible();
    await expect(page.getByText(`${activeEvent.startDate} to ${activeEvent.endDate}`)).toBeVisible();
    await expect(page.getByRole("button", { name: /confirm registration/i })).toBeEnabled();

    console.log("CODEVALID_TEST_ASSERTION_OK:events_dashboard_displays_active_events");
  } finally {
    await recorder.save(testInfo);
  }
});
