import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Registration form is enabled when current date is within event date window", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_form_enabled_within_date_window",
    testTitle: testInfo.title,
  });

  const startDate = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const endDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];

  const events = [
    {
      id: "event_open",
      title: "Open Registration Event",
      description: "Event currently accepting attendees",
      startDate,
      endDate,
      location: "Room A",
      registrationCount: 0,
    },
  ];

  await recorder.record("Seed authenticated session");
  await setupAuthenticatedSession(page);

  await recorder.record("Mock event and empty registrations for currently open event");
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

  await recorder.record("Assert active registration status is visible");
  await expect(page.getByText("Registration Active")).toBeVisible();
  await expect(page.getByText("You can register attendees for this event.")).toBeVisible();

  await recorder.record("Assert all form inputs are enabled and editable");
  await expect(page.locator('[name="name"]')).toBeEnabled();
  await expect(page.locator('[name="email"]')).toBeEnabled();
  await expect(page.locator('[name="phone"]')).toBeEnabled();
  await expect(page.getByRole("button", { name: "Confirm Registration" })).toBeEnabled();

  await page.locator('[name="name"]').fill("Jane Smith");
  await page.locator('[name="email"]').fill("jane@smith.com");
  await page.locator('[name="phone"]').fill("+1 (555) 000-0000");

  await expect(page.locator('[name="name"]')).toHaveValue("Jane Smith");
  await expect(page.locator('[name="email"]')).toHaveValue("jane@smith.com");
  await expect(page.locator('[name="phone"]')).toHaveValue("+1 (555) 000-0000");

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_form_enabled_within_date_window");
  await recorder.save(testInfo);
});
