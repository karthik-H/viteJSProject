import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMockRoutes, teardownMockRoutes } from "../../mock/mock-server.js";

test.describe("Registration form validates required fields", () => {
  test.beforeEach(async ({ page }) => {
    await setupMockRoutes(page);
  });

  test.afterEach(async ({ page }) => {
    await teardownMockRoutes(page);
  });

  test("registration form validation missing fields", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "registration_form_validation_missing_fields",
      testTitle: testInfo.title,
    });

    recorder.record("Navigate to home page");
    await page.goto("/");

    const nameInput = page.locator('[name="name"]');
    const emailInput = page.locator('[name="email"]');
    const phoneInput = page.locator('[name="phone"]');
    const submitButton = page.getByRole("button", { name: /Confirm Registration/i });

    recorder.record("Fill required fields except email");
    await nameInput.fill("Validation User");
    await phoneInput.fill("+1 (555) 200-4000");
    await expect(emailInput).toHaveValue("");

    let registrationCallCount = 0;
    await page.route("**/api/registrations", async (route) => {
      if (route.request().method() === "POST") {
        registrationCallCount += 1;
      }
      await route.fallback();
    });

    recorder.record("Attempt to submit with missing email");
    await submitButton.click();

    recorder.record("Verify client-side validation error and no registration API POST is sent");
    await expect(page.getByText("Email is required")).toBeVisible();
    await expect(emailInput).toHaveValue("");
    await expect.poll(() => registrationCallCount).toBe(0);

    console.log("CODEVALID_TEST_ASSERTION_OK:registration_form_validation_missing_fields");
    await recorder.save(testInfo);
  });
});
