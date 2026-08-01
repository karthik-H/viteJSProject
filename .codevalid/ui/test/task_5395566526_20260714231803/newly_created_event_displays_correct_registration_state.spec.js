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

test("Newly created event immediately displays correct registration button state", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "newly_created_event_displays_correct_registration_state",
    testTitle: testInfo.title,
  });

  await freezeDate(page, "2024-06-20");
  await setupAuthenticatedSession(page);

  const events = [];

  await page.route("**/api/events", async (route) => {
    const method = route.request().method();
    if (method === "GET") {
      return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(events) });
    }
    if (method === "POST") {
      const body = JSON.parse(route.request().postData() || "{}");
      const newEvent = {
        id: "event_created_001",
        title: body.title,
        description: body.description || "",
        startDate: body.startDate,
        endDate: body.endDate,
        location: body.location,
        registrationCount: 0,
      };
      events.push(newEvent);
      return route.fulfill({ status: 201, contentType: "application/json", body: JSON.stringify(newEvent) });
    }
    return route.continue();
  });

  await page.route("**/api/registrations/*", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([]) });
  });

  recorder.record("Open the Events page");
  await page.goto("/events");
  await expect(page.getByRole("heading", { name: "Events Management Setup" })).toBeVisible();

  recorder.record("Open the create event form");
  await page.getByRole("button", { name: "Create New Event" }).click();

  recorder.record("Fill the new event form with active dates");
  await page.locator('[name="title"]').fill("Launch Week Demo Day");
  await page.locator('[name="description"]').fill("Product showcase and demos.");
  await page.locator('[name="location"]').fill("Auditorium A");
  await page.locator('[name="startDate"]').fill("2024-06-15");
  await page.locator('[name="endDate"]').fill("2024-06-25");

  recorder.record("Publish the event and verify it appears with zero registrations");
  await page.getByRole("button", { name: "Publish Event" }).click();
  await expect(page.getByText("Event created successfully!")).toBeVisible();
  await expect(page.getByText("Launch Week Demo Day")).toBeVisible();
  await expect(page.getByText("2024-06-15 to 2024-06-25")).toBeVisible();
  await expect(page.getByText("0 registered")).toBeVisible();

  recorder.record("Navigate to the Home registration desk and verify the event is immediately active for registration");
  await page.goto("/");
  await expect(page.getByText("Launch Week Demo Day")).toBeVisible();
  await expect(page.getByText("Registration Active")).toBeVisible();
  await expect(page.getByRole("button", { name: "Confirm Registration" })).toBeEnabled();

  console.log("CODEVALID_TEST_ASSERTION_OK:newly_created_event_displays_correct_registration_state");
  await recorder.save(testInfo);
});
