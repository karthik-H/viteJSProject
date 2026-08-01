import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Registration is blocked when email is already registered for the event", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_blocked_duplicate_email",
    testTitle: testInfo.title,
  });

  const startDate = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const endDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];

  const events = [
    {
      id: "event_duplicate",
      title: "Duplicate Check Event",
      description: "Open event",
      startDate,
      endDate,
      location: "Hall 2",
      registrationCount: 1,
    },
  ];

  const existingRegistrations = [
    {
      id: "reg_existing_001",
      eventId: "event_duplicate",
      name: "Existing User",
      email: "test@example.com",
      phone: "+1 (555) 000-1111",
      registeredAt: new Date().toISOString(),
    },
  ];

  await recorder.record("Seed authenticated session");
  await setupAuthenticatedSession(page);

  await recorder.record("Mock open event with one existing registration");
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
      body: JSON.stringify(existingRegistrations),
    });
  });

  await recorder.record("Mock duplicate-email backend rejection");
  await page.route("**/api/registrations", async (route) => {
    if (route.request().method() !== "POST") return route.continue();
    await route.fulfill({
      status: 400,
      contentType: "application/json",
      body: JSON.stringify({
        message: "This email is already registered for this event.",
      }),
    });
  });

  await recorder.record("Open Home page");
  await page.goto("/");

  await recorder.record("Submit duplicate email registration");
  await page.locator('[name="name"]').fill("Retry User");
  await page.locator('[name="email"]').fill("test@example.com");
  await page.locator('[name="phone"]').fill("+1 (555) 000-2222");
  await page.getByRole("button", { name: "Confirm Registration" }).click();

  await recorder.record("Assert duplicate email error is shown and count remains unchanged");
  await expect(page.getByText("This email is already registered for this event.")).toBeVisible();
  await expect(page.getByText("1 Total")).toBeVisible();
  await expect(page.getByText("Existing User")).toBeVisible();
  await expect(page.getByText("test@example.com")).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_blocked_duplicate_email");
  await recorder.save(testInfo);
});
