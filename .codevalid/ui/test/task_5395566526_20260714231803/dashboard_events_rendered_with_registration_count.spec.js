import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupAuthenticatedSession } from "../../helpers/mock-api.js";

test("Dashboard renders all events with correct registration counts", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "dashboard_events_rendered_with_registration_count",
    testTitle: testInfo.title,
  });

  const today = new Date().toISOString().split("T")[0];
  const activeEnd = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const futureStart = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const futureEnd = new Date(Date.now() + 21 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];

  const events = [
    {
      id: "event_alpha",
      title: "Alpha Summit",
      description: "Current event",
      startDate: today,
      endDate: activeEnd,
      location: "Main Hall",
      registrationCount: 2,
    },
    {
      id: "event_beta",
      title: "Beta Workshop",
      description: "Future event",
      startDate: futureStart,
      endDate: futureEnd,
      location: "Online",
      registrationCount: 0,
    },
  ];

  const registrationsByEventId = {
    event_alpha: [
      {
        id: "reg_001",
        eventId: "event_alpha",
        name: "Alice Example",
        email: "alice@example.com",
        phone: "+1 (555) 000-1001",
        registeredAt: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
      },
      {
        id: "reg_002",
        eventId: "event_alpha",
        name: "Bob Example",
        email: "bob@example.com",
        phone: "+1 (555) 000-1002",
        registeredAt: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
      },
    ],
    event_beta: [],
  };

  await recorder.record("Seed authenticated session before app boot");
  await setupAuthenticatedSession(page);

  await recorder.record("Mock GET /api/events with events and registration counts");
  await page.route("**/api/events", async (route) => {
    if (route.request().method() !== "GET") {
      return route.continue();
    }
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(events),
    });
  });

  await recorder.record("Mock GET /api/registrations/:eventId for selected event");
  await page.route("**/api/registrations/*", async (route) => {
    if (route.request().method() !== "GET") {
      return route.continue();
    }
    const url = new URL(route.request().url());
    const eventId = url.pathname.split("/").pop();
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(registrationsByEventId[eventId] ?? []),
    });
  });

  await recorder.record("Navigate to the protected Home page");
  await page.goto("/");

  await recorder.record("Assert dashboard heading and first selected event details are visible");
  await expect(page.getByRole("heading", { name: "Registration Desk" })).toBeVisible();
  await expect(page.getByText("Event Dates:")).toBeVisible();
  await expect(page.getByText("Alpha Summit")).toBeVisible();
  await expect(page.getByText(`${today}`)).toBeVisible();
  await expect(page.getByText(`${activeEnd}`)).toBeVisible();

  await recorder.record("Assert registration count from GET /api/registrations is rendered in audience summary");
  await expect(page.getByText("2 Total")).toBeVisible();
  await expect(page.getByText("Alice Example")).toBeVisible();
  await expect(page.getByText("alice@example.com")).toBeVisible();
  await expect(page.getByText("Bob Example")).toBeVisible();
  await expect(page.getByText("bob@example.com")).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:dashboard_events_rendered_with_registration_count");
  await recorder.save(testInfo);
});
