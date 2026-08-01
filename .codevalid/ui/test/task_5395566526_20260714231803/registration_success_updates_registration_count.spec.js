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

test("Successful registration updates the registration count on the event card", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "registration_success_updates_registration_count",
    testTitle: testInfo.title,
  });

  await freezeDate(page, "2024-06-20");
  await setupAuthenticatedSession(page);

  const events = [
    {
      id: "event_count_update",
      title: "Open House",
      description: "Registration count should update",
      startDate: "2024-06-20",
      endDate: "2024-07-05",
      location: "Main Hall",
      registrationCount: 0,
    },
  ];
  const registrations = [];

  await page.route("**/api/events", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(events) });
  });

  await page.route("**/api/registrations/*", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(registrations) });
  });

  await page.route("**/api/registrations", async (route) => {
    if (route.request().method() !== "POST") return route.continue();
    const body = JSON.parse(route.request().postData() || "{}");
    const newRegistration = {
      id: "reg_new_001",
      eventId: body.eventId,
      name: body.name,
      email: body.email,
      phone: body.phone,
      registeredAt: "2024-06-20T12:00:00.000Z",
    };
    registrations.unshift(newRegistration);
    events[0].registrationCount += 1;
    return route.fulfill({ status: 201, contentType: "application/json", body: JSON.stringify(newRegistration) });
  });

  recorder.record("Navigate to the home registration dashboard");
  await page.goto("/");

  recorder.record("Verify initial registered audience total is zero");
  await expect(page.getByText("0 Total")).toBeVisible();
  await expect(page.getByText("No Registered Attendees")).toBeVisible();

  recorder.record("Fill attendee registration form");
  await page.locator('[name="name"]').fill("Jane Smith");
  await page.locator('[name="email"]').fill("jane@smith.com");
  await page.locator('[name="phone"]').fill("+1 (555) 000-0000");

  recorder.record("Submit the registration");
  await page.getByRole("button", { name: "Confirm Registration" }).click();

  recorder.record("Verify success message and registration count update without reload");
  await expect(page.getByText("Attendee registered successfully!")).toBeVisible();
  await expect(page.getByText("1 Total")).toBeVisible();
  await expect(page.getByText("Jane Smith")).toBeVisible();
  await expect(page.getByText("jane@smith.com")).toBeVisible();
  await expect(page.locator('[name="name"]')).toHaveValue("");
  await expect(page.locator('[name="email"]')).toHaveValue("");
  await expect(page.locator('[name="phone"]')).toHaveValue("");

  console.log("CODEVALID_TEST_ASSERTION_OK:registration_success_updates_registration_count");
  await recorder.save(testInfo);
});
