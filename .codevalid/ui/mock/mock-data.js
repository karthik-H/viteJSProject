/**
 * mock-data.js
 *
 * Static mock data used by the mock server to respond to API requests
 * during Playwright test runs. Mirrors the in-memory store shape used
 * by the real Express backend (backend/server.js).
 */

export const mockUsers = [
  {
    id: "user_alice001",
    username: "alice",
    email: "alice@example.com",
    password: "password123",
    fullName: "Alice Johnson",
    phone: "+1 (555) 100-0001",
    organization: "Acme Corp",
  },
  {
    id: "user_bob002",
    username: "bob",
    email: "bob@example.com",
    password: "secret456",
    fullName: "Bob Smith",
    phone: "+1 (555) 100-0002",
    organization: "Beta LLC",
  },
];

// Today's date as YYYY-MM-DD
const today = new Date().toISOString().split("T")[0];
// A date 30 days from now
const futureDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
  .toISOString()
  .split("T")[0];
// A date 60 days from now
const laterDate = new Date(Date.now() + 60 * 24 * 60 * 60 * 1000)
  .toISOString()
  .split("T")[0];

export const mockEvents = [
  {
    id: "event_conf2026",
    title: "Tech Conference 2026",
    description: "Annual technology conference covering AI, cloud, and DevOps.",
    startDate: today,
    endDate: futureDate,
    location: "Convention Center, San Francisco, CA",
    registrationCount: 2,
  },
  {
    id: "event_workshop2026",
    title: "React Workshop",
    description: "Hands-on workshop on React 19 and modern frontend patterns.",
    startDate: futureDate,
    endDate: laterDate,
    location: "Online",
    registrationCount: 0,
  },
];

export const mockRegistrations = [
  {
    id: "reg_001",
    eventId: "event_conf2026",
    name: "Carol Davis",
    email: "carol@example.com",
    phone: "+1 (555) 200-0001",
    registeredAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: "reg_002",
    eventId: "event_conf2026",
    name: "Dave Wilson",
    email: "dave@example.com",
    phone: "+1 (555) 200-0002",
    registeredAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString(),
  },
];

/**
 * Returns mock sign-in response for a given email + password.
 * Returns null if credentials do not match any mock user.
 */
export function getMockSignInResponse(email, password) {
  const user = mockUsers.find(
    (u) =>
      u.email.toLowerCase() === email?.toLowerCase() && u.password === password
  );
  if (!user) return null;

  const { password: _, ...userWithoutPassword } = user;
  return {
    user: userWithoutPassword,
    token: `mock-jwt-token-for-${user.id}`,
  };
}

/**
 * Returns mock sign-up response for a new user.
 * Returns an error object if username or email already exists.
 */
export function getMockSignUpResponse({ username, email, password, fullName, phone, organization }) {
  const exists = mockUsers.find(
    (u) =>
      u.email.toLowerCase() === email?.toLowerCase() ||
      u.username.toLowerCase() === username?.toLowerCase()
  );
  if (exists) {
    return { error: "Username or Email already registered." };
  }

  const newUser = {
    id: `user_mock_${Date.now()}`,
    username,
    email,
    password,
    fullName,
    phone: phone || "",
    organization: organization || "",
  };
  mockUsers.push(newUser);

  const { password: _, ...userWithoutPassword } = newUser;
  return {
    user: userWithoutPassword,
    token: `mock-jwt-token-for-${newUser.id}`,
  };
}
