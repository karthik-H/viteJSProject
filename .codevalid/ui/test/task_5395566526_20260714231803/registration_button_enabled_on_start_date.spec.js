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

test("Registration button is enabled exactly on event start date", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_button_enabled_on_start_date",
    testTitle: testInfo.title,
  });

  await freezeDate(page, "2024-06-20");
  await setupAuthenticatedSession(page);
  await mockHomeScenario(page, {
    id: "event_start_boundary",
    title: "Start Day Workshop",
    description: "Boundary open state",
    startDate: "2024-06-20",
    endDate: "2024-07-05",
    location: "Studio 1",
    registrationCount: 0,
  });

  recorder.record("Navigate to the registration dashboard home page");
  await page.goto("/");

  recorder.record("Verify registration is open on the exact start date");
  await expect(page.getByText("Registration Active")).toBeVisible();
  await expect(page.getByRole("button", { name: "Confirm Registration" })).toBeEnabled();
  await expect(page.locator('[name="name"]')).toBeEnabled();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_button_enabled_on_start_date");
  await recorder.save(testInfo);
});
