/**
 * mock-server.js
 *
 * Playwright route-interceptor helpers that intercept API calls made by the
 * Vite dev server proxy and return mock data defined in mock-data.js.
 *
 * Usage in a test file:
 *
 *   import { setupMockRoutes, teardownMockRoutes } from "../mock/mock-server.js";
 *
 *   test.beforeEach(async ({ page }) => {
 *     await setupMockRoutes(page);
 *   });
 *
 *   test.afterEach(async ({ page }) => {
 *     await teardownMockRoutes(page);
 *   });
 *
 * The helpers intercept the following endpoints:
 *   POST /api/auth/signin
 *   POST /api/auth/signup
 *   GET  /api/events
 *   POST /api/events
 *   GET  /api/registrations/:eventId
 *   POST /api/registrations
 */

import {
  mockEvents,
  mockRegistrations,
  getMockSignInResponse,
  getMockSignUpResponse,
} from "./mock-data.js";

/**
 * Register all API mock routes on the given Playwright Page.
 *
 * @param {import("@playwright/test").Page} page
 */
export async function setupMockRoutes(page) {
  // --- POST /api/auth/signin ---
  await page.route("**/api/auth/signin", async (route) => {
    const request = route.request();
    if (request.method() !== "POST") {
      return route.continue();
    }

    let body = {};
    try {
      body = JSON.parse(request.postData() || "{}");
    } catch {
      // ignore parse errors
    }

    const result = getMockSignInResponse(body.email, body.password);
    if (!result) {
      return route.fulfill({
        status: 401,
        contentType: "application/json",
        body: JSON.stringify({ message: "Invalid email or password." }),
      });
    }

    return route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(result),
    });
  });

  // --- POST /api/auth/signup ---
  await page.route("**/api/auth/signup", async (route) => {
    const request = route.request();
    if (request.method() !== "POST") {
      return route.continue();
    }

    let body = {};
    try {
      body = JSON.parse(request.postData() || "{}");
    } catch {
      // ignore parse errors
    }

    const { username, email, password, fullName } = body;
    if (!username || !email || !password || !fullName) {
      return route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({
          message: "Username, email, password, and full name are required.",
        }),
      });
    }

    const result = getMockSignUpResponse(body);
    if (result.error) {
      return route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({ message: result.error }),
      });
    }

    return route.fulfill({
      status: 201,
      contentType: "application/json",
      body: JSON.stringify(result),
    });
  });

  // --- GET /api/events ---
  await page.route("**/api/events", async (route) => {
    const request = route.request();

    if (request.method() === "GET") {
      const sorted = [...mockEvents].sort(
        (a, b) => new Date(a.startDate) - new Date(b.startDate)
      );
      return route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(sorted),
      });
    }

    if (request.method() === "POST") {
      let body = {};
      try {
        body = JSON.parse(request.postData() || "{}");
      } catch {
        // ignore
      }

      const { title, startDate, endDate, location } = body;
      if (!title || !startDate || !endDate || !location) {
        return route.fulfill({
          status: 400,
          contentType: "application/json",
          body: JSON.stringify({
            message: "Title, start date, end date, and location are required.",
          }),
        });
      }

      const newEvent = {
        id: `event_mock_${Date.now()}`,
        title,
        description: body.description || "",
        startDate,
        endDate,
        location,
        registrationCount: 0,
      };
      mockEvents.push(newEvent);

      return route.fulfill({
        status: 201,
        contentType: "application/json",
        body: JSON.stringify(newEvent),
      });
    }

    return route.continue();
  });

  // --- GET /api/registrations/:eventId ---
  await page.route("**/api/registrations/*", async (route) => {
    const request = route.request();

    if (request.method() === "GET") {
      const url = new URL(request.url());
      const segments = url.pathname.split("/");
      const eventId = segments[segments.length - 1];

      const event = mockEvents.find((e) => e.id === eventId);
      if (!event) {
        return route.fulfill({
          status: 404,
          contentType: "application/json",
          body: JSON.stringify({ message: "Event not found." }),
        });
      }

      const regs = mockRegistrations
        .filter((r) => r.eventId === eventId)
        .sort((a, b) => new Date(b.registeredAt) - new Date(a.registeredAt));

      return route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(regs),
      });
    }

    return route.continue();
  });

  // --- POST /api/registrations ---
  await page.route("**/api/registrations", async (route) => {
    const request = route.request();
    if (request.method() !== "POST") {
      return route.continue();
    }

    let body = {};
    try {
      body = JSON.parse(request.postData() || "{}");
    } catch {
      // ignore
    }

    const { eventId, name, email, phone } = body;
    if (!eventId || !name || !email || !phone) {
      return route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({
          message: "Event, name, email, and phone number are required.",
        }),
      });
    }

    const event = mockEvents.find((e) => e.id === eventId);
    if (!event) {
      return route.fulfill({
        status: 404,
        contentType: "application/json",
        body: JSON.stringify({ message: "Event not found." }),
      });
    }

    const today = new Date().toISOString().split("T")[0];
    if (today < event.startDate) {
      return route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({
          message: `Registration has not opened yet. Registration opens on ${event.startDate}.`,
        }),
      });
    }
    if (today > event.endDate) {
      return route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({
          message: `Registration is closed. The event ended on ${event.endDate}.`,
        }),
      });
    }

    const alreadyRegistered = mockRegistrations.some(
      (r) =>
        r.eventId === eventId && r.email.toLowerCase() === email.toLowerCase()
    );
    if (alreadyRegistered) {
      return route.fulfill({
        status: 400,
        contentType: "application/json",
        body: JSON.stringify({
          message: "This email is already registered for this event.",
        }),
      });
    }

    const newReg = {
      id: `reg_mock_${Date.now()}`,
      eventId,
      name,
      email,
      phone,
      registeredAt: new Date().toISOString(),
    };
    mockRegistrations.push(newReg);
    event.registrationCount = (event.registrationCount || 0) + 1;

    return route.fulfill({
      status: 201,
      contentType: "application/json",
      body: JSON.stringify(newReg),
    });
  });
}

/**
 * Remove all previously registered mock routes from the page.
 *
 * @param {import("@playwright/test").Page} page
 */
export async function teardownMockRoutes(page) {
  await page.unrouteAll({ behavior: "ignoreErrors" });
}
