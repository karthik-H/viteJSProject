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

async function mockHomeScenario(page, event) {
  await page.route("**/api/events", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([event]) });
  });
  await page.route("**/api/registrations/*", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([]) });
  });
}

test("Registration button is disabled when current date is before event start date", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_button_disabled_before_start_date",
    testTitle: testInfo.title,
  });

  await freezeDate(page, "2024-06-20");
  await setupAuthenticatedSession(page);
  await mockHomeScenario(page, {
    id: "event_future",
    title: "Future Expo",
    description: "Registration not open yet",
    startDate: "2024-06-25",
    endDate: "2024-07-05",
    location: "Virtual",
    registrationCount: 0,
  });

  recorder.record("Navigate to the registration dashboard home page");
  await page.goto("/");

  recorder.record("Verify upcoming registration message and disabled controls");
  await expect(page.getByText("Registration Upcoming")).toBeVisible();
  await expect(page.getByText("Registration opens on 2024-06-25.")).toBeVisible();
  await expect(page.locator('[name="name"]')).toBeDisabled();
  await expect(page.locator('[name="email"]')).toBeDisabled();
  await expect(page.locator('[name="phone"]')).toBeDisabled();
  await expect(page.getByRole("button", { name: "Confirm Registration" })).toBeDisabled();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_button_disabled_before_start_date");
  await recorder.save(testInfo);
});
