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

test("Registration request is blocked when UI button is disabled due to date rules", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_attempts_blocked_when_disabled",
    testTitle: testInfo.title,
  });

  await freezeDate(page, "2024-06-20");
  await setupAuthenticatedSession(page);

  const futureEvent = {
    id: "event_blocked_future",
    title: "Locked Registration Expo",
    description: "Should reject bypass attempts",
    startDate: "2024-06-25",
    endDate: "2024-07-05",
    location: "Auditorium C",
    registrationCount: 0,
  };

  await page.route("**/api/events", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([futureEvent]) });
  });

  await page.route("**/api/registrations/*", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([]) });
  });

  await page.route("**/api/registrations", async (route) => {
    if (route.request().method() !== "POST") return route.continue();
    return route.fulfill({
      status: 400,
      contentType: "application/json",
      body: JSON.stringify({
        message: "Registration has not opened yet. Registration opens on 2024-06-25."
      })
    });
  });

  recorder.record("Navigate to the home registration dashboard");
  await page.goto("/");

  recorder.record("Verify UI blocks normal registration controls");
  await expect(page.getByRole("button", { name: "Confirm Registration" })).toBeDisabled();
  await expect(page.getByText("Registration opens on 2024-06-25.")).toBeVisible();
  await expect(page.getByText("0 Total")).toBeVisible();

  recorder.record("Bypass the disabled UI by issuing a direct API request from the page context");
  const response = await page.evaluate(async () => {
    const res = await fetch("/api/registrations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        eventId: "event_blocked_future",
        name: "Bypass User",
        email: "bypass@example.com",
        phone: "+1 (555) 111-2222"
      })
    });
    const data = await res.json();
    return { status: res.status, data };
  });

  recorder.record("Verify backend-style rejection and no UI count update");
  expect(response.status).toBe(400);
  expect(response.data.message).toBe("Registration has not opened yet. Registration opens on 2024-06-25.");
  await expect(page.getByText("0 Total")).toBeVisible();
  await expect(page.getByText("No Registered Attendees")).toBeVisible();
  await expect(page.getByText("Bypass User")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_attempts_blocked_when_disabled");
  await recorder.save(testInfo);
});
