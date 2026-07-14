import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupAuthenticatedSession,
  mockProtectedHomePageApis,
  mockRegistrationsApi,
  mockRegistrationSubmit,
} from "../../helpers/mock-api.js";

const formatDate = (date) => date.toISOString().split("T")[0];

test("Allow attendee registration on the event start date", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "allow_registration_on_event_start_date",
    testName: "Allow attendee registration on the event start date",
  });

  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);
  const todayStr = formatDate(today);

  const startingTodayEvent = {
    id: "event_start_today_001",
    title: "Opening Day Event",
    description: "Registration opens today.",
    startDate: todayStr,
    endDate: formatDate(tomorrow),
    location: "Atrium",
    registrationCount: 0,
  };

  const expectedPayload = {
    eventId: startingTodayEvent.id,
    name: "Alex Carter",
    email: "alex.carter@example.com",
    phone: "+1 (555) 111-2222",
  };

  const createdRegistration = {
    id: "reg_start_today_001",
    ...expectedPayload,
    registeredAt: new Date().toISOString(),
  };

  try {
    await recorder.step("Setup authenticated session for event starting today");
    await setupAuthenticatedSession(page);
    await mockProtectedHomePageApis(page, { events: [startingTodayEvent] });
    await mockRegistrationsApi(page, {
      byEventId: {
        [startingTodayEvent.id]: [],
      },
    });
    await mockRegistrationSubmit(page, {
      expectedPayload,
      status: 201,
      responseBody: createdRegistration,
    });

    await recorder.step("Open dashboard and confirm registration is active on start date");
    await page.goto("/");
    await expect(page.getByText("Registration Active")).toBeVisible();
    await expect(page.getByText("You can register attendees for this event.")).toBeVisible();
    await expect(page.getByRole("button", { name: /confirm registration/i })).toBeEnabled();

    await recorder.step("Register attendee on the event start date");
    await page.locator('[name="name"]').fill(expectedPayload.name);
    await page.locator('[name="email"]').fill(expectedPayload.email);
    await page.locator('[name="phone"]').fill(expectedPayload.phone);
    await page.getByRole("button", { name: /confirm registration/i }).click();

    await recorder.step("Assert successful registration outcome");
    await expect(page.getByText("Attendee registered successfully!")).toBeVisible();
    await expect(page.getByText(createdRegistration.name)).toBeVisible();
    await expect(page.getByText("1 Total")).toBeVisible();

    console.log("CODEVALID_TEST_ASSERTION_OK:allow_registration_on_event_start_date");
  } finally {
    await recorder.save(testInfo);
  }
});
