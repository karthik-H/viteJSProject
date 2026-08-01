import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Backend error messages are shown to user on registration failure", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_error_displayed_for_backend_failure",
    testTitle: testInfo.title,
  });

  const startDate = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const endDate = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];

  const events = [
    {
      id: "event_backend_future",
      title: "Backend Future Event",
      description: "Event scheduled later",
      startDate,
      endDate,
      location: "Hall 4",
      registrationCount: 0,
    },
  ];

  const backendMessage = `Registration has not opened yet. Registration opens on ${startDate}.`;

  await recorder.record("Seed authenticated session");
  await setupAuthenticatedSession(page);

  await recorder.record("Mock future event and empty registrations");
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

  await recorder.record("Override disabled form in DOM and mock backend 400 response");
  await page.route("**/api/registrations", async (route) => {
    if (route.request().method() !== "POST") return route.continue();
    await route.fulfill({
      status: 400,
      contentType: "application/json",
      body: JSON.stringify({ message: backendMessage }),
    });
  });

  await recorder.record("Open Home page");
  await page.goto("/");

  await recorder.record("Confirm future registration message is visible");
  await expect(page.getByText("Registration Upcoming")).toBeVisible();
  await expect(page.getByText(`Registration opens on ${startDate}.`)).toBeVisible();

  await recorder.record("Force-enable the disabled inputs and submit button to exercise backend error rendering path");
  await page.locator('[name="name"]').evaluate((el) => el.removeAttribute("disabled"));
  await page.locator('[name="email"]').evaluate((el) => el.removeAttribute("disabled"));
  await page.locator('[name="phone"]').evaluate((el) => el.removeAttribute("disabled"));
  await page.getByRole("button", { name: "Confirm Registration" }).evaluate((el) => el.removeAttribute("disabled"));

  await page.locator('[name="name"]').fill("Future User");
  await page.locator('[name="email"]').fill("future@example.com");
  await page.locator('[name="phone"]').fill("+1 (555) 000-3333");
  await page.getByRole("button", { name: "Confirm Registration" }).click();

  await recorder.record("Assert backend message is displayed exactly to the user");
  await expect(page.getByText(backendMessage)).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_error_displayed_for_backend_failure");
  await recorder.save(testInfo);
});
