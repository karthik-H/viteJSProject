import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Newly created event immediately displays correct registration button state", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "newly_created_event_displays_correct_registration_state",
    testTitle: testInfo.title,
  });

  await recorder.record("Freeze browser date to 2024-06-20");
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

  const createdEvent = {
    id: "event_created_001",
    title: "Mid-June Launch",
    description: "New event created from Events page.",
    startDate: "2024-06-15",
    endDate: "2024-06-25",
    location: "Auditorium A",
    registrationCount: 0,
  };

  await recorder.record("Mock empty event list initially and successful event creation");
  await page.route("**/api/events", async (route) => {
    const method = route.request().method();
    if (method === "GET") {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([]) });
      return;
    }
    if (method === "POST") {
      const payload = JSON.parse(route.request().postData() || "{}");
      expect(payload).toEqual({
        title: "Mid-June Launch",
        description: "New event created from Events page.",
        startDate: "2024-06-15",
        endDate: "2024-06-25",
        location: "Auditorium A",
      });
      await route.fulfill({ status: 201, contentType: "application/json", body: JSON.stringify(createdEvent) });
      return;
    }
    await route.continue();
  });

  await recorder.record("Open Events dashboard");
  await page.goto("/events");

  await recorder.record("Open create event form");
  await page.getByRole("button", { name: "Create New Event" }).click();

  await recorder.record("Fill create event form with exact field locators");
  await page.locator('[name="title"]').fill("Mid-June Launch");
  await page.locator('[name="description"]').fill("New event created from Events page.");
  await page.locator('[name="location"]').fill("Auditorium A");
  await page.locator('[name="startDate"]').fill("2024-06-15");
  await page.locator('[name="endDate"]').fill("2024-06-25");

  await recorder.record("Submit new event");
  await page.getByRole("button", { name: "Publish Event" }).click();

  await recorder.record("Verify success toast and new event card are shown on Events page");
  await expect(page.getByText("Event created successfully!", { exact: true })).toBeVisible();
  await expect(page.getByText("Mid-June Launch", { exact: true })).toBeVisible();
  await expect(page.getByText("2024-06-15 to 2024-06-25", { exact: true })).toBeVisible();
  await expect(page.getByText("0 registered", { exact: true })).toBeVisible();
  await expect(page.getByText("Active", { exact: true })).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:newly_created_event_displays_correct_registration_state");
  await recorder.save(testInfo);
});
