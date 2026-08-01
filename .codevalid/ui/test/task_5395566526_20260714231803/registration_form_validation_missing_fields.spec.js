import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Registration form prevents submission when required fields are missing", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_form_validation_missing_fields",
    testTitle: testInfo.title,
  });

  const startDate = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const endDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];

  const events = [
    {
      id: "event_validation",
      title: "Validation Event",
      description: "Open event",
      startDate,
      endDate,
      location: "Hall 3",
      registrationCount: 0,
    },
  ];

  let postCallCount = 0;

  await recorder.record("Seed authenticated session");
  await setupAuthenticatedSession(page);

  await recorder.record("Mock open event and empty registrations");
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

  await page.route("**/api/registrations", async (route) => {
    if (route.request().method() !== "POST") return route.continue();
    postCallCount += 1;
    await route.fulfill({
      status: 201,
      contentType: "application/json",
      body: JSON.stringify({}),
    });
  });

  await recorder.record("Open Home page");
  await page.goto("/");

  await recorder.record("Leave email blank and attempt submission");
  await page.locator('[name="name"]').fill("Jane Smith");
  await page.locator('[name="phone"]').fill("+1 (555) 000-0000");
  await page.getByRole("button", { name: "Confirm Registration" }).click();

  await recorder.record("Assert inline validation appears and no registration POST is made");
  await expect(page.getByText("Email is required")).toBeVisible();
  expect(postCallCount).toBe(0);
  await expect(page.getByText("No Registered Attendees")).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_form_validation_missing_fields");
  await recorder.save(testInfo);
});
