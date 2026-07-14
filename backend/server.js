import express from "express";
import cors from "cors";
import morgan from "morgan";
import { users, events, registrations } from "./data/store.js";

const app = express();
const PORT = process.env.PORT || 6713;

// Middleware
app.use(cors());
app.use(express.json());
app.use(morgan("dev"));

// Helper function to generate IDs
const generateId = (prefix) => `${prefix}_${Math.random().toString(36).substr(2, 9)}`;

// Health check
app.get("/health", (req, res) => {
  res.status(200).json({ status: "ok" });
});

// --- Authentication Endpoints ---

// User Sign Up
app.post("/api/auth/signup", (req, res) => {
  const { username, email, password, fullName, phone, organization } = req.body;

  // Validation
  if (!username || !email || !password || !fullName) {
    return res.status(400).json({ message: "Username, email, password, and full name are required." });
  }

  // Check if user already exists
  const existingUser = users.find(u => u.email.toLowerCase() === email.toLowerCase() || u.username.toLowerCase() === username.toLowerCase());
  if (existingUser) {
    return res.status(400).json({ message: "Username or Email already registered." });
  }

  // Create new user
  const newUser = {
    id: generateId("user"),
    username,
    email,
    password, // Store in plain text for in-memory simplicity
    fullName,
    phone: phone || "",
    organization: organization || ""
  };

  users.push(newUser);

  // Return user without password
  const { password: _, ...userWithoutPassword } = newUser;
  return res.status(201).json({
    user: userWithoutPassword,
    token: `simulated-jwt-token-for-${newUser.id}`
  });
});

// User Sign In
app.post("/api/auth/signin", (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: "Email and password are required." });
  }

  const user = users.find(u => u.email.toLowerCase() === email.toLowerCase());

  if (!user || user.password !== password) {
    return res.status(401).json({ message: "Invalid email or password." });
  }

  const { password: _, ...userWithoutPassword } = user;
  return res.status(200).json({
    user: userWithoutPassword,
    token: `simulated-jwt-token-for-${user.id}`
  });
});

// --- Events Endpoints ---

// Get all events
app.get("/api/events", (req, res) => {
  // Return events list sorted by start date
  const sortedEvents = [...events].sort((a, b) => new Date(a.startDate) - new Date(b.startDate));
  
  // Calculate registration count for each event to send back to UI
  const eventsWithCount = sortedEvents.map(event => {
    const regCount = registrations.filter(r => r.eventId === event.id).length;
    return { ...event, registrationCount: regCount };
  });

  return res.status(200).json(eventsWithCount);
});

// Create a new event
app.post("/api/events", (req, res) => {
  const { title, description, startDate, endDate, location } = req.body;

  if (!title || !startDate || !endDate || !location) {
    return res.status(400).json({ message: "Title, start date, end date, and location are required." });
  }

  if (new Date(startDate) > new Date(endDate)) {
    return res.status(400).json({ message: "Start date must be before or equal to the end date." });
  }

  const newEvent = {
    id: generateId("event"),
    title,
    description: description || "",
    startDate,
    endDate,
    location
  };

  events.push(newEvent);
  return res.status(201).json({ ...newEvent, registrationCount: 0 });
});

// --- Registrations Endpoints ---

// Get registrations for a specific event
app.get("/api/registrations/:eventId", (req, res) => {
  const { eventId } = req.params;

  // Check if event exists
  const event = events.find(e => e.id === eventId);
  if (!event) {
    return res.status(404).json({ message: "Event not found." });
  }

  const eventRegistrations = registrations
    .filter(r => r.eventId === eventId)
    .sort((a, b) => new Date(b.registeredAt) - new Date(a.registeredAt));

  return res.status(200).json(eventRegistrations);
});

// Register a user for an event
app.post("/api/registrations", (req, res) => {
  const { eventId, name, email, phone } = req.body;

  if (!eventId || !name || !email || !phone) {
    return res.status(400).json({ message: "Event, name, email, and phone number are required." });
  }

  // Find the event
  const event = events.find(e => e.id === eventId);
  if (!event) {
    return res.status(404).json({ message: "Event not found." });
  }

  // Business Logic: Check if registration date is within the event start and end dates
  const todayStr = new Date().toISOString().split("T")[0];

  if (todayStr < event.startDate) {
    return res.status(400).json({
      message: `Registration has not opened yet. Registration opens on ${event.startDate}.`
    });
  }

  if (todayStr > event.endDate) {
    return res.status(400).json({
      message: `Registration is closed. The event ended on ${event.endDate}.`
    });
  }

  // Check if already registered (optional, let's allow unique emails per event)
  const isAlreadyRegistered = registrations.some(
    r => r.eventId === eventId && r.email.toLowerCase() === email.toLowerCase()
  );
  if (isAlreadyRegistered) {
    return res.status(400).json({ message: "This email is already registered for this event." });
  }

  // Create registration
  const newRegistration = {
    id: generateId("reg"),
    eventId,
    name,
    email,
    phone,
    registeredAt: new Date().toISOString()
  };

  registrations.push(newRegistration);
  return res.status(201).json(newRegistration);
});

// Start Server
app.listen(PORT, () => {
  console.log(`Express server running on http://localhost:${PORT}`);
});
