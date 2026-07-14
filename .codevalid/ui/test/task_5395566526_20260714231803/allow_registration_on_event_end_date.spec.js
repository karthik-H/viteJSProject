import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupAuthenticatedSession,
  mockProtectedHomePageApis,
  mockRegistrationsApi,
  mockRegistrationSubmit,
} from "../../helpers/mock-api.js";

const formatDate = (date) => date.toISOString().split("T")[0];

test("Allow attendee registration on the event end date", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "allow_registration_on_event_end_date",
    testName: "Allow attendee registration on the event end date",
  });

  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  const todayStr = formatDate(today);

  const endingTodayEvent = {
    id: "event_end_today_001",
    title: "Closing Day Event",
    description: "Registration remains open through today.",
    startDate: formatDate(yesterday),
    endDate: todayStr,
    location: "Conference Room B",
    registrationCount: 0,
  };

  const expectedPayload = {
    eventId: endingTodayEvent.id,
    name: "Morgan Lee",
    email: "morgan.lee@example.com",
    phone: "+1 (555) 333-4444",
  };

  const createdRegistration = {
    id: "reg_end_today_001",
    ...expectedPayload,
    registeredAt: new Date().toISOString(),
  };

  try {
    await recorder.step("Setup authenticated session for event ending today");
    await setupAuthenticatedSession(page);
    await mockProtectedHomePageApis(page, { events: [endingTodayEvent] });
    await mockRegistrationsApi(page, {
      byEventId: {
        [endingTodayEvent.id]: [],
      },
    });
    await mockRegistrationSubmit(page, {
      expectedPayload,
      status: 201,
      responseBody: createdRegistration,
    });

    await recorder.step("Open dashboard and confirm registration is active on end date");
    await page.goto("/");
    await expect(page.getByText("Registration Active")).toBeVisible();
    await expect(page.getByRole("button", { name: /confirm registration/i })).toBeEnabled();

    await recorder.step("Submit attendee registration on the event end date");
    await page.locator('[name="name"]').fill(expectedPayload.name);
    await page.locator('[name="email"]').fill(expectedPayload.email);
    await page.locator('[name="phone"]').fill(expectedPayload.phone);
    await page.getByRole("button", { name: /confirm registration/i }).click();

    await recorder.step("Assert registration succeeds on the final allowed day");
    await expect(page.getByText("Attendee registered successfully!")).toBeVisible();
    await expect(page.getByText(createdRegistration.name)).toBeVisible();
    await expect(page.getByText(createdRegistration.email)).toBeVisible();
    await expect(page.getByText("1 Total")).toBeVisible();

    console.log("CODEVALID_TEST_ASSERTION_OK:allow_registration_on_event_end_date");
  } finally {
    await recorder.save(testInfo);
  }
});
