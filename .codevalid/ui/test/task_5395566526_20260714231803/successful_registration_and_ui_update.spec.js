import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMockRoutes, teardownMockRoutes } from "../../mock/mock-server.js";

test.describe("Successful registration updates count and clears form", () => {
  test.beforeEach(async ({ page }) => {
    await setupMockRoutes(page);
    await page.route("**/api/events", async (route) => {
      const request = route.request();
      if (request.method() !== "GET") {
        return route.fallback();
      }

      return route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([
          {
            id: "event_open_zero_001",
            title: "Open Registration Expo",
            description: "Open event with no current registrations.",
            startDate: "2024-01-01",
            endDate: "2099-12-31",
            location: "Expo Center",
            registrationCount: 0,
          },
        ]),
      });
    });

    await page.route("**/api/registrations/event_open_zero_001", async (route) => {
      if (route.request().method() !== "GET") {
        return route.fallback();
      }

      return route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([]),
      });
    });
  });

  test.afterEach(async ({ page }) => {
    await teardownMockRoutes(page);
  });

  test("successful registration and ui update", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "successful_registration_and_ui_update",
      testTitle: testInfo.title,
    });

    recorder.record("Navigate to home page with open event and zero registrations");
    await page.goto("/");

    recorder.record("Verify initial zero registration state");
    await expect(page.getByText("0 Total")).toBeVisible();
    await expect(page.getByRole("heading", { name: "No Registered Attendees" })).toBeVisible();

    const nameInput = page.locator('[name="name"]');
    const emailInput = page.locator('[name="email"]');
    const phoneInput = page.locator('[name="phone"]');
    const submitButton = page.getByRole("button", { name: /Confirm Registration/i });

    recorder.record("Fill registration form");
    await nameInput.fill("New Attendee");
    await emailInput.fill("new.attendee@example.com");
    await phoneInput.fill("+1 (555) 300-0001");

    recorder.record("Submit registration");
    await submitButton.click();

    recorder.record("Verify success state, updated count, and cleared form");
    await expect(page.getByText("Attendee registered successfully!")).toBeVisible();
    await expect(page.getByText("1 Total")).toBeVisible();
    await expect(page.getByText("New Attendee")).toBeVisible();
    await expect(nameInput).toHaveValue("");
    await expect(emailInput).toHaveValue("");
    await expect(phoneInput).toHaveValue("");

    console.log("CODEVALID_TEST_ASSERTION_OK:successful_registration_and_ui_update");
    await recorder.save(testInfo);
  });
});
