import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";

const AUTH_KEY = "auth";

async function freezeDate(page, isoDate) {
  const frozenIso = `${isoDate}T12:00:00.000Z`;
  await page.addInitScript(({ now }) => {
    const RealDate = Date;
    class MockDate extends RealDate {
      constructor(...args) {
        if (args.length === 0) super(now);
        else super(...args);
      }
      static now() { return new RealDate(now).getTime(); }
      static parse(value) { return RealDate.parse(value); }
      static UTC(...args) { return RealDate.UTC(...args); }
    }
    Object.setPrototypeOf(MockDate, RealDate);
    // eslint-disable-next-line no-global-assign
    Date = MockDate;
  }, { now: frozenIso });
}

async function setupAuthenticatedSession(page) {
  await page.addInitScript((storageKey) => {
    window.localStorage.setItem(storageKey, JSON.stringify({
      token: "mock-jwt-token",
      user: { id: "user_alice001", email: "alice@example.com" }
    }));
  }, AUTH_KEY);
}

async function mockHomeScenario(page, { events, registrations = [] }) {
  await page.route("**/api/events", async (route) => {
    const method = route.request().method();
    if (method === "GET") {
      const sorted = [...events].sort((a, b) => new Date(a.startDate) - new Date(b.startDate));
      return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(sorted) });
    }
    return route.continue();
  });

  await page.route("**/api/registrations/*", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(registrations) });
  });

  await page.route("**/api/registrations", async (route) => {
    if (route.request().method() !== "POST") return route.continue();
    return route.fulfill({ status: 201, contentType: "application/json", body: JSON.stringify({}) });
  });
}

test("Registration button is enabled when current date is within event start and end dates", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_button_enabled_within_date_range",
    testTitle: testInfo.title,
  });

  await freezeDate(page, "2024-06-20");
  await setupAuthenticatedSession(page);
  await mockHomeScenario(page, {
    events: [
      {
        id: "event_in_range",
        title: "Summer Community Meetup",
        description: "Open registration window",
        startDate: "2024-06-15",
        endDate: "2024-06-25",
        location: "Auditorium A",
        registrationCount: 0,
      },
    ],
  });

  recorder.record("Navigate to the registration dashboard home page");
  await page.goto("/");

  recorder.record("Verify the selected event date range is shown");
  await expect(page.getByText("Event Dates:")).toContainText("2024-06-15");
  await expect(page.getByText("Event Dates:")).toContainText("2024-06-25");

  recorder.record("Verify registration is active and the Confirm Registration button is enabled");
  await expect(page.getByText("Registration Active")).toBeVisible();
  await expect(page.getByText("You can register attendees for this event.")).toBeVisible();
  await expect(page.locator('[name="name"]')).toBeEnabled();
  await expect(page.locator('[name="email"]')).toBeEnabled();
  await expect(page.locator('[name="phone"]')).toBeEnabled();
  await expect(page.getByRole("button", { name: "Confirm Registration" })).toBeEnabled();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_button_enabled_within_date_range");
  await recorder.save(testInfo);
});
