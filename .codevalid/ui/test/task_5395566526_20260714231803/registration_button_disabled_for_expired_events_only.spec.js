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

test("Expired events do not show registration button even if displayed", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_button_disabled_for_expired_events_only",
    testTitle: testInfo.title,
  });

  await freezeDate(page, "2024-06-20");
  await setupAuthenticatedSession(page);

  await page.route("**/api/events", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    return route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([
        {
          id: "event_expired_only",
          title: "Past Networking Session",
          description: "Expired event remains visible",
          startDate: "2024-06-10",
          endDate: "2024-06-18",
          location: "Virtual",
          registrationCount: 0,
        },
      ])
    });
  });

  await page.route("**/api/registrations/*", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([]) });
  });

  recorder.record("Navigate to the Events page and confirm the expired event is displayed");
  await page.goto("/events");
  await expect(page.getByText("Past Networking Session")).toBeVisible();
  await expect(page.getByText("2024-06-10 to 2024-06-18")).toBeVisible();
  await expect(page.getByText("Closed")).toBeVisible();

  recorder.record("Navigate to the Home registration desk and confirm no registration is possible for the expired event");
  await page.goto("/");
  await expect(page.getByText("Registration Closed")).toBeVisible();
  await expect(page.getByText("Registration closed on 2024-06-18.")).toBeVisible();
  await expect(page.locator('[name="name"]')).toBeDisabled();
  await expect(page.locator('[name="email"]')).toBeDisabled();
  await expect(page.locator('[name="phone"]')).toBeDisabled();
  await expect(page.getByRole("button", { name: "Confirm Registration" })).toBeDisabled();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_button_disabled_for_expired_events_only");
  await recorder.save(testInfo);
});
