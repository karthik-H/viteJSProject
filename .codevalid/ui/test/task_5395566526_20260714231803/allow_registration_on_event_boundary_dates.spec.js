import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  setupAuthenticatedSession,
  mockProtectedHomePageApis,
  mockRegistrationsApi,
  mockRegistrationSubmit,
} from "../../helpers/mock-api.js";

test("Allow attendee registration on start and end boundary dates", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "allow_registration_on_event_boundary_dates",
    testName: "Allow attendee registration on start and end boundary dates",
  });

  const today = new Date().toISOString().split("T")[0];
  const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split("T")[0];

  const startBoundaryEvent = {
    id: "event_boundary_start_001",
    title: "Starts Today Conference",
    description: "Boundary event that starts today.",
    startDate: today,
    endDate: tomorrow,
    location: "Hall A",
    registrationCount: 0,
  };
  const endBoundaryEvent = {
    id: "event_boundary_end_001",
    title: "Ends Today Meetup",
    description: "Boundary event that ends today.",
    startDate: yesterday,
    endDate: today,
    location: "Hall B",
    registrationCount: 0,
  };

  const startBoundaryRegistration = {
    eventId: startBoundaryEvent.id,
    name: "Boundary Start User",
    email: "start.boundary@example.com",
    phone: "+1 (555) 100-1000",
  };
  const endBoundaryRegistration = {
    eventId: endBoundaryEvent.id,
    name: "Boundary End User",
    email: "end.boundary@example.com",
    phone: "+1 (555) 200-2000",
  };

  let registrationCallCount = 0;

  try {
    await recorder.step("Set up authenticated session and boundary-date event mocks");
    await setupAuthenticatedSession(page);
    await mockProtectedHomePageApis(page, {
      events: [startBoundaryEvent, endBoundaryEvent],
    });
    await mockRegistrationsApi(page, {
      byEventId: {
        [startBoundaryEvent.id]: [],
        [endBoundaryEvent.id]: [],
      },
    });
    await mockRegistrationSubmit(page, {
      status: 201,
      responseBody: {
        id: "reg_boundary_fallback",
        registeredAt: "2026-07-14T12:00:00.000Z",
      },
    });

    await page.unroute("**/api/registrations");
    await page.route("**/api/registrations", async (route, request) => {
      if (request.method() !== "POST") {
        return route.fallback();
      }

      const body = request.postDataJSON?.() ?? {};
      registrationCallCount += 1;

      if (registrationCallCount === 1) {
        expect(body).toEqual(startBoundaryRegistration);
        return route.fulfill({
          status: 201,
          contentType: "application/json",
          body: JSON.stringify({
            id: "reg_boundary_start_001",
            ...body,
            registeredAt: "2026-07-14T12:00:00.000Z",
          }),
        });
      }

      if (registrationCallCount === 2) {
        expect(body).toEqual(endBoundaryRegistration);
        return route.fulfill({
          status: 201,
          contentType: "application/json",
          body: JSON.stringify({
            id: "reg_boundary_end_001",
            ...body,
            registeredAt: "2026-07-14T12:10:00.000Z",
          }),
        });
      }

      throw new Error(`Unexpected registration submission count: ${registrationCallCount}`);
    });

    await recorder.step("Open the dashboard home page");
    await page.goto("/");

    await recorder.step("Register an attendee for the event whose start date is today");
    await expect(page.getByText("Starts Today Conference")).toBeVisible();
    await expect(page.getByText("Registration Active")).toBeVisible();
    await page.locator('[name="name"]').fill(startBoundaryRegistration.name);
    await page.locator('[name="email"]').fill(startBoundaryRegistration.email);
    await page.locator('[name="phone"]').fill(startBoundaryRegistration.phone);
    await page.getByRole("button", { name: /confirm registration/i }).click();
    await expect(page.getByText("Attendee registered successfully!")).toBeVisible();
    await expect(page.getByText(startBoundaryRegistration.name)).toBeVisible();

    await recorder.step("Switch to the event whose end date is today");
    await page.selectOption("select", endBoundaryEvent.id);
    await expect(page.getByText("Ends Today Meetup")).toBeVisible();
    await expect(page.getByText("Registration Active")).toBeVisible();
    await expect(page.getByText("You can register attendees for this event.")).toBeVisible();

    await recorder.step("Register an attendee for the event whose end date is today");
    await page.locator('[name="name"]').fill(endBoundaryRegistration.name);
    await page.locator('[name="email"]').fill(endBoundaryRegistration.email);
    await page.locator('[name="phone"]').fill(endBoundaryRegistration.phone);
    await page.getByRole("button", { name: /confirm registration/i }).click();

    await recorder.step("Verify registration succeeds on both boundary dates");
    await expect(page.getByText("Attendee registered successfully!")).toBeVisible();
    await expect(page.getByText(endBoundaryRegistration.name)).toBeVisible();
    await expect(page.getByText(endBoundaryRegistration.email)).toBeVisible();
    await expect(page.locator('[name="name"]')).toHaveValue("");
    await expect(page.locator('[name="email"]')).toHaveValue("");
    await expect(page.locator('[name="phone"]')).toHaveValue("");

    console.log("CODEVALID_TEST_ASSERTION_OK:allow_registration_on_event_boundary_dates");
  } finally {
    await recorder.save(testInfo);
  }
});
