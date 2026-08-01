import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Registration form is disabled and shows message when current date is after event end", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_form_disabled_after_end_date",
    testTitle: testInfo.title,
  });

  const startDate = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const endDate = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];

  const events = [
    {
      id: "event_closed",
      title: "Closed Event",
      description: "Event already ended",
      startDate,
      endDate,
      location: "Past Hall",
      registrationCount: 0,
    },
  ];

  await recorder.record("Seed authenticated session");
  await setupAuthenticatedSession(page);

  await recorder.record("Mock ended event and empty registrations");
  await page.route("**/api/events", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(events),
    });
  });

  await page.route("**/api/registrations/*", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify([]),
    });
  });

  await recorder.record("Open Home page");
  await page.goto("/");

  await recorder.record("Assert closed registration status and message are shown");
  await expect(page.getByText("Registration Closed")).toBeVisible();
  await expect(page.getByText(`Registration closed on ${endDate}.`)).toBeVisible();

  await recorder.record("Assert form fields and submit button are disabled");
  await expect(page.locator('[name="name"]')).toBeDisabled();
  await expect(page.locator('[name="email"]')).toBeDisabled();
  await expect(page.locator('[name="phone"]')).toBeDisabled();
  await expect(page.getByRole("button", { name: "Confirm Registration" })).toBeDisabled();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_form_disabled_after_end_date");
  await recorder.save(testInfo);
});
