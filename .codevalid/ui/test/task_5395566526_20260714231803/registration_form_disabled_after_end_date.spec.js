import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMockRoutes, teardownMockRoutes } from "../../mock/mock-server.js";

test.describe("Registration form is disabled after event end date", () => {
  test.beforeEach(async ({ page }) => {
    await setupMockRoutes(page);
    await page.route("**/api/events", async (route) => {
      if (route.request().method() !== "GET") {
        return route.fallback();
      }

      return route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([
          {
            id: "event_past_001",
            title: "Archived Summit",
            description: "Past event used to verify closed registration state.",
            startDate: "2024-01-01",
            endDate: "2024-01-02",
            location: "Main Hall",
            registrationCount: 0,
          },
        ]),
      });
    });
  });

  test.afterEach(async ({ page }) => {
    await teardownMockRoutes(page);
  });

  test("registration form disabled after end date", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "registration_form_disabled_after_end_date",
      testTitle: testInfo.title,
    });

    recorder.record("Navigate to home page with closed event fixture");
    await page.goto("/");

    recorder.record("Verify closed registration status and message");
    await expect(page.getByText("Registration Closed")).toBeVisible();
    await expect(page.getByText("Registration closed on 2024-01-02.")).toBeVisible();

    recorder.record("Verify all form controls are disabled for past event");
    const nameInput = page.locator('[name="name"]');
    const emailInput = page.locator('[name="email"]');
    const phoneInput = page.locator('[name="phone"]');
    const submitButton = page.getByRole("button", { name: /Confirm Registration/i });

    await expect(nameInput).toBeDisabled();
    await expect(emailInput).toBeDisabled();
    await expect(phoneInput).toBeDisabled();
    await expect(submitButton).toBeDisabled();

    console.log("CODEVALID_TEST_ASSERTION_OK:registration_form_disabled_after_end_date");
    await recorder.save(testInfo);
  });
});
