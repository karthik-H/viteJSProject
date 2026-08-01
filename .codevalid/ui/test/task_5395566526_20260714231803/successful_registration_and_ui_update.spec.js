import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Successful registration updates registration count and form state", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "successful_registration_and_ui_update",
    testTitle: testInfo.title,
  });

  const startDate = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const endDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];

  const events = [
    {
      id: "event_success",
      title: "Success Event",
      description: "Open event",
      startDate,
      endDate,
      location: "Hall 1",
      registrationCount: 0,
    },
  ];

  const createdRegistration = {
    id: "reg_created_001",
    eventId: "event_success",
    name: "Jane Smith",
    email: "jane@smith.com",
    phone: "+1 (555) 000-0000",
    registeredAt: new Date().toISOString(),
  };

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

  await recorder.record("Mock successful POST /api/registrations response");
  await page.route("**/api/registrations", async (route) => {
    if (route.request().method() !== "POST") return route.continue();
    const payload = JSON.parse(route.request().postData() || "{}");
    expect(payload).toEqual({
      eventId: "event_success",
      name: "Jane Smith",
      email: "jane@smith.com",
      phone: "+1 (555) 000-0000",
    });
    await route.fulfill({
      status: 201,
      contentType: "application/json",
      body: JSON.stringify(createdRegistration),
    });
  });

  await recorder.record("Open Home page");
  await page.goto("/");

  await recorder.record("Fill registration form and submit");
  await page.locator('[name="name"]').fill("Jane Smith");
  await page.locator('[name="email"]').fill("jane@smith.com");
  await page.locator('[name="phone"]').fill("+1 (555) 000-0000");
  await page.getByRole("button", { name: "Confirm Registration" }).click();

  await recorder.record("Assert success feedback, incremented count, and cleared form fields");
  await expect(page.getByText("Attendee registered successfully!")).toBeVisible();
  await expect(page.getByText("1 Total")).toBeVisible();
  await expect(page.getByText("Jane Smith")).toBeVisible();
  await expect(page.getByText("jane@smith.com")).toBeVisible();
  await expect(page.locator('[name="name"]')).toHaveValue("");
  await expect(page.locator('[name="email"]')).toHaveValue("");
  await expect(page.locator('[name="phone"]')).toHaveValue("");

  console.log("CODEVALID_TEST_ASSERTION_OK:successful_registration_and_ui_update");
  await recorder.save(testInfo);
});
