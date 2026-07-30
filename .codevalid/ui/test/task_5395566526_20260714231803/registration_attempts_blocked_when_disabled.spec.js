import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Registration request is blocked when UI button is disabled due to date rules", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_attempts_blocked_when_disabled",
    testTitle: testInfo.title,
  });

  await recorder.record("Freeze browser date to 2024-06-20 before the event registration opens");
  await page.addInitScript(() => {
    const fixed = new Date("2024-06-20T12:00:00.000Z");
    const RealDate = Date;
    class MockDate extends RealDate {
      constructor(...args) { super(args.length === 0 ? fixed.toISOString() : ...args); }
      static now() { return fixed.getTime(); }
      static parse(value) { return RealDate.parse(value); }
      static UTC(...args) { return RealDate.UTC(...args); }
    }
    window.Date = MockDate;
  });

  await recorder.record("Seed authenticated session");
  await setupAuthenticatedSession(page);

  const event = {
    id: "event_blocked_window",
    title: "Blocked Registration Event",
    description: "Registration is not yet allowed.",
    startDate: "2024-06-25",
    endDate: "2024-07-05",
    location: "Main Hall",
    registrationCount: 0,
  };

  await recorder.record("Mock event, registrations, and backend-style 400 rejection on direct POST");
  await page.route("**/api/events", async (route) => {
    if (route.request().method() === "GET") {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([event]) });
      return;
    }
    await route.continue();
  });
  await page.route("**/api/registrations/*", async (route) => {
    if (route.request().method() === "GET") {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([]) });
      return;
    }
    await route.continue();
  });
  await page.route("**/api/registrations", async (route) => {
    if (route.request().method() === "POST") {
      await route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({
          message: "Registration has not opened yet. Registration opens on 2024-06-25.",
        }),
      });
      return;
    }
    await route.continue();
  });

  await recorder.record("Open registration dashboard");
  await page.goto("/");

  await recorder.record("Verify normal UI is disabled for registration");
  await expect(page.getByRole("button", { name: /Confirm Registration/i })).toBeDisabled();
  await expect(page.getByText("0 Total", { exact: true })).toBeVisible();

  await recorder.record("Bypass the disabled UI by issuing a direct API request from the browser context");
  const response = await page.evaluate(async () => {
    const res = await fetch("/api/registrations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        eventId: "event_blocked_window",
        name: "Blocked User",
        email: "blocked@example.com",
        phone: "+1 (555) 999-0000",
      }),
    });
    const data = await res.json();
    return { status: res.status, body: data };
  });

  await recorder.record("Assert backend rejection is returned and UI state remains unchanged");
  expect(response.status).toBe(400);
  expect(response.body).toEqual({
    message: "Registration has not opened yet. Registration opens on 2024-06-25.",
  });
  await expect(page.getByText("0 Total", { exact: true })).toBeVisible();
  await expect(page.getByText("Blocked User", { exact: true })).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_attempts_blocked_when_disabled");
  await recorder.save(testInfo);
});
