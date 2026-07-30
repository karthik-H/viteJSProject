import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { setupMockRoutes, teardownMockRoutes } from "../../mock/mock-server.js";

test.describe("Duplicate email registration is blocked", () => {
  test.beforeEach(async ({ page }) => {
    await setupMockRoutes(page);
  });

  test.afterEach(async ({ page }) => {
    await teardownMockRoutes(page);
  });

  test("registration blocked duplicate email", async ({ page }, testInfo) => {
    const recorder = new ExecutionRecorder({
      testId: "registration_blocked_duplicate_email",
      testTitle: testInfo.title,
    });

    recorder.record("Navigate to home page");
    await page.goto("/");

    recorder.record("Use active event and confirm current registration count");
    await expect(page.getByText("2 Total")).toBeVisible();

    const nameInput = page.locator('[name="name"]');
    const emailInput = page.locator('[name="email"]');
    const phoneInput = page.locator('[name="phone"]');
    const submitButton = page.getByRole("button", { name: /Confirm Registration/i });

    recorder.record("Fill form with already registered email");
    await nameInput.fill("Duplicate User");
    await emailInput.fill("carol@example.com");
    await phoneInput.fill("+1 (555) 999-1111");

    recorder.record("Submit duplicate registration");
    await submitButton.click();

    recorder.record("Verify duplicate email error and unchanged registration count");
    await expect(page.getByText("This email is already registered for this event.")).toBeVisible();
    await expect(page.getByText("2 Total")).toBeVisible();

    console.log("CODEVALID_TEST_ASSERTION_OK:registration_blocked_duplicate_email");
    await recorder.save(testInfo);
  });
});
