import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupAuthenticatedSession,
  mockProtectedHomePageApis,
  mockRegistrationsApi,
} from "../../helpers/mock-api.js";

test("Display active events on dashboard", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "home_displays_active_events",
    testName: "Display active events on dashboard",
  });

  const today = new Date().toISOString().split("T")[0];
  const activeEvent = {
    id: "event_active_001",
    title: "CodeValid Summit",
    description: "Active event visible on the dashboard.",
    startDate: today,
    endDate: today,
    location: "Main Hall",
    registrationCount: 2,
  };

  try {
    await recorder.step("Set up authenticated session and dashboard API mocks");
    await setupAuthenticatedSession(page);
    await mockProtectedHomePageApis(page, { events: [activeEvent] });
    await mockRegistrationsApi(page, {
      byEventId: {
        [activeEvent.id]: [],
      },
    });

    await recorder.step("Navigate to the dashboard home page");
    await page.goto("/");

    await recorder.step("Verify active event details are displayed on the dashboard");
    await expect(page).toHaveURL(/\/$/);
    await expect(page.getByRole("heading", { name: "Registration Desk" })).toBeVisible();
    await expect(page.getByText("CodeValid Summit")).toBeVisible();
    await expect(page.getByText(`Event Dates: ${today} to ${today}.`)).toBeVisible();
    await expect(page.getByText("Registration Active")).toBeVisible();
    await expect(page.getByText("You can register attendees for this event.")).toBeVisible();

    console.log("CODEVALID_TEST_ASSERTION_OK:home_displays_active_events");
  } finally {
    await recorder.save(testInfo);
  }
});
