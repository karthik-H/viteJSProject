import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Successful registration updates the registration count on the event card", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_success_updates_registration_count",
    testTitle: testInfo.title,
  });

  await recorder.record("Freeze browser date to 2024-06-20 for an active registration window");
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
    id: "event_count_update",
    title: "Count Update Event",
    description: "Registration count should increment.",
    startDate: "2024-06-20",
    endDate: "2024-07-05",
    location: "Main Hall",
    registrationCount: 0,
  };

  const newRegistration = {
    id: "reg_new_001",
    eventId: "event_count_update",
    name: "Jane Smith",
    email: "jane@smith.com",
    phone: "+1 (555) 000-0000",
    registeredAt: "2024-06-20T12:00:00.000Z",
  };

  await recorder.record("Mock events, existing registrations, and successful registration POST");
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
      const payload = JSON.parse(route.request().postData() || "{}");
      expect(payload).toEqual({
        eventId: "event_count_update",
        name: "Jane Smith",
        email: "jane@smith.com",
        phone: "+1 (555) 000-0000",
      });
      await route.fulfill({ status: 201, contentType: "application/json", body: JSON.stringify(newRegistration) });
      return;
    }
    await route.continue();
  });

  await recorder.record("Open registration dashboard");
  await page.goto("/");

  await recorder.record("Verify initial attendee total is zero");
  await expect(page.getByText("0 Total", { exact: true })).toBeVisible();

  await recorder.record("Fill registration form fields");
  await page.locator('[name="name"]').fill("Jane Smith");
  await page.locator('[name="email"]').fill("jane@smith.com");
  await page.locator('[name="phone"]').fill("+1 (555) 000-0000");

  await recorder.record("Submit registration");
  await page.getByRole("button", { name: /Confirm Registration/i }).click();

  await recorder.record("Verify success message, attendee total increment, and table row appearance without reload");
  await expect(page.getByText("Attendee registered successfully!", { exact: true })).toBeVisible();
  await expect(page.getByText("1 Total", { exact: true })).toBeVisible();
  await expect(page.getByText("Jane Smith", { exact: true })).toBeVisible();
  await expect(page.getByText("jane@smith.com", { exact: true })).toBeVisible();
  await expect(page.getByText("+1 (555) 000-0000", { exact: true })).toBeVisible();
  await expect(page.locator('[name="name"]')).toHaveValue("");
  await expect(page.locator('[name="email"]')).toHaveValue("");
  await expect(page.locator('[name="phone"]')).toHaveValue("");

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_success_updates_registration_count");
  await recorder.save(testInfo);
});
