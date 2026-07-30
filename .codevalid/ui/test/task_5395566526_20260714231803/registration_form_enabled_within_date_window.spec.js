import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMockRoutes, teardownMockRoutes } from "../../mock/mock-server.js";

test.describe("Registration form is enabled when current date is within event date window", () => {
  test.beforeEach(async ({ page }) => {
    await setupMockRoutes(page);
  });

  test.afterEach(async ({ page }) => {
    await teardownMockRoutes(page);
  });

  test("registration form is enabled within date window", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "registration_form_enabled_within_date_window",
      testTitle: testInfo.title,
    });

    recorder.record("Navigate to home page");
    await page.goto("/");

    recorder.record("Wait for active event registration form to load");
    await expect(page.getByRole("heading", { name: "Register User" })).toBeVisible();
    await expect(page.getByText("Registration Active")).toBeVisible();
    await expect(page.getByText("You can register attendees for this event.")).toBeVisible();

    recorder.record("Verify form inputs are enabled and editable for active event");
    const nameInput = page.locator('[name="name"]');
    const emailInput = page.locator('[name="email"]');
    const phoneInput = page.locator('[name="phone"]');
    const submitButton = page.getByRole("button", { name: /Confirm Registration/i });

    await expect(nameInput).toBeEnabled();
    await expect(emailInput).toBeEnabled();
    await expect(phoneInput).toBeEnabled();
    await expect(submitButton).toBeEnabled();

    recorder.record("Fill inputs to confirm editability");
    await nameInput.fill("Jane Smith");
    await emailInput.fill("jane@smith.com");
    await phoneInput.fill("+1 (555) 000-0000");

    await expect(nameInput).toHaveValue("Jane Smith");
    await expect(emailInput).toHaveValue("jane@smith.com");
    await expect(phoneInput).toHaveValue("+1 (555) 000-0000");

    console.log("CODEVALID_TEST_ASSERTION_OK:registration_form_enabled_within_date_window");
    await recorder.save(testInfo);
  });
});
