import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupAuthenticatedSession,
  mockProtectedHomePageApis,
  mockRegistrationsApi,
  mockRegistrationSubmit,
} from "../../helpers/mock-api.js";

test("Register attendee during active event period", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "register_attendee_within_event_date_range",
    testName: "Register attendee during active event period",
  });

  const today = new Date().toISOString().split("T")[0];
  const activeEvent = {
    id: "event_active_002",
    title: "Open Registration Expo",
    description: "Event currently accepting registrations.",
    startDate: today,
    endDate: today,
    location: "Expo Center",
    registrationCount: 0,
  };
  const registrationPayload = {
    eventId: activeEvent.id,
    name: "Jane Smith",
    email: "jane@smith.com",
    phone: "+1 (555) 000-0000",
  };
  const createdRegistration = {
    id: "reg_created_002",
    ...registrationPayload,
    registeredAt: "2026-07-14T12:00:00.000Z",
  };

  try {
    await recorder.step("Set up authenticated session and mocks for an active event registration");
    await setupAuthenticatedSession(page);
    await mockProtectedHomePageApis(page, { events: [activeEvent] });
    await mockRegistrationsApi(page, {
      byEventId: {
        [activeEvent.id]: [],
      },
    });
    await mockRegistrationSubmit(page, {
      expectedPayload: registrationPayload,
      status: 201,
      responseBody: createdRegistration,
    });

    await recorder.step("Open the dashboard home page");
    await page.goto("/");

    await recorder.step("Fill the attendee registration form for the active event");
    await expect(page.getByText("Registration Active")).toBeVisible();
    await page.locator('[name="name"]').fill(registrationPayload.name);
    await page.locator('[name="email"]').fill(registrationPayload.email);
    await page.locator('[name="phone"]').fill(registrationPayload.phone);

    await recorder.step("Submit the attendee registration");
    await page.getByRole("button", { name: /confirm registration/i }).click();

    await recorder.step("Verify the attendee was registered successfully");
    await expect(page.getByText("Attendee registered successfully!")).toBeVisible();
    await expect(page.getByText(registrationPayload.name)).toBeVisible();
    await expect(page.getByText(registrationPayload.email)).toBeVisible();
    await expect(page.getByText(registrationPayload.phone)).toBeVisible();
    await expect(page.locator('[name="name"]')).toHaveValue("");
    await expect(page.locator('[name="email"]')).toHaveValue("");
    await expect(page.locator('[name="phone"]')).toHaveValue("");

    console.log("CODEVALID_TEST_ASSERTION_OK:register_attendee_within_event_date_range");
  } finally {
    await recorder.save(testInfo);
  }
});
