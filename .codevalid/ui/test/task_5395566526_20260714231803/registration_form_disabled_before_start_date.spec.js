import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMockRoutes, teardownMockRoutes } from "../../mock/mock-server.js";

test.describe("Registration form is disabled before event start date", () => {
  test.beforeEach(async ({ page }) => {
    await setupMockRoutes(page);
  });

  test.afterEach(async ({ page }) => {
    await teardownMockRoutes(page);
  });

  test("registration form disabled before start date", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "registration_form_disabled_before_start_date",
      testTitle: testInfo.title,
    });

    recorder.record("Navigate to home page");
    await page.goto("/");

    recorder.record("Select future event");
    const eventSelector = page.locator("select");
    await expect(eventSelector).toBeVisible();
    await eventSelector.selectOption("event_workshop2026");

    recorder.record("Verify status badge and upcoming registration message");
    await expect(page.getByText("Registration Upcoming")).toBeVisible();
    await expect(page.getByText(/Registration opens on .*\./)).toBeVisible();

    recorder.record("Verify all form controls are disabled");
    const nameInput = page.locator('[name="name"]');
    const emailInput = page.locator('[name="email"]');
    const phoneInput = page.locator('[name="phone"]');
    const submitButton = page.getByRole("button", { name: /Confirm Registration/i });

    await expect(nameInput).toBeDisabled();
    await expect(emailInput).toBeDisabled();
    await expect(phoneInput).toBeDisabled();
    await expect(submitButton).toBeDisabled();

    console.log("CODEVALID_TEST_ASSERTION_OK:registration_form_disabled_before_start_date");
    await recorder.save(testInfo);
  });
});
