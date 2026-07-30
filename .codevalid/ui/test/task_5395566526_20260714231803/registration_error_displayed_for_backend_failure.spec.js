import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMockRoutes, teardownMockRoutes } from "../../mock/mock-server.js";

test.describe("Backend date-related error is shown to user", () => {
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
            id: "event_future_force_submit_001",
            title: "Future Launch Event",
            description: "Future event for backend error display validation.",
            startDate: "2099-01-15",
            endDate: "2099-01-20",
            location: "Virtual",
            registrationCount: 0,
          },
        ]),
      });
    });

    await page.route("**/api/registrations/event_future_force_submit_001", async (route) => {
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

  test("registration error displayed for backend failure", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "registration_error_displayed_for_backend_failure",
      testTitle: testInfo.title,
    });

    recorder.record("Navigate to home page with future event");
    await page.goto("/");

    recorder.record("Confirm upcoming registration status is visible");
    await expect(page.getByText("Registration Upcoming")).toBeVisible();
    await expect(page.getByText("Registration opens on 2099-01-15.")).toBeVisible();

    const nameInput = page.locator('[name="name"]');
    const emailInput = page.locator('[name="email"]');
    const phoneInput = page.locator('[name="phone"]');
    const submitButton = page.getByRole("button", { name: /Confirm Registration/i });

    recorder.record("Force enable disabled form controls to simulate backend error rendering path");
    await nameInput.evaluate((el) => el.removeAttribute("disabled"));
    await emailInput.evaluate((el) => el.removeAttribute("disabled"));
    await phoneInput.evaluate((el) => el.removeAttribute("disabled"));
    await submitButton.evaluate((el) => el.removeAttribute("disabled"));

    recorder.record("Fill form and submit future event registration");
    await nameInput.fill("Future User");
    await emailInput.fill("future.user@example.com");
    await phoneInput.fill("+1 (555) 600-7000");
    await submitButton.click();

    recorder.record("Verify exact backend date-window error message is displayed");
    await expect(page.getByText("Registration has not opened yet. Registration opens on 2099-01-15.")).toBeVisible();

    console.log("CODEVALID_TEST_ASSERTION_OK:registration_error_displayed_for_backend_failure");
    await recorder.save(testInfo);
  });
});
