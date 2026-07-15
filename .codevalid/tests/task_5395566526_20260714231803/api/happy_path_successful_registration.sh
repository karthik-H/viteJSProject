#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TODAY="$(date -u +%F)"
EVENT_TITLE="Active Event ${CASE_SUFFIX}"
ATTENDEE_EMAIL="john.doe.${CASE_SUFFIX}@example.com"
TMP_DIR="$(mktemp -d)"
EVENT_REQUEST_BODY="$TMP_DIR/event_request.json"
EVENT_RESPONSE_HEADERS="$TMP_DIR/event_response_headers.txt"
EVENT_RESPONSE_BODY="$TMP_DIR/event_response_body.json"
REQUEST_BODY_FILE="$TMP_DIR/request_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"

cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — create an active event for registration"
cat > "$EVENT_REQUEST_BODY" <<EOF
{
  "title": "${EVENT_TITLE}",
  "description": "Active registration event",
  "startDate": "${TODAY}",
  "endDate": "${TODAY}",
  "location": "Dashboard Hall"
}
EOF

echo "PREREQ: creating active event via ${BASE_URL}/api/events"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$EVENT_REQUEST_BODY"
EVENT_HTTP_CODE="$(curl -sS -D "$EVENT_RESPONSE_HEADERS" -o "$EVENT_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data @"$EVENT_REQUEST_BODY")"
echo "RESPONSE_STATUS: $EVENT_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$EVENT_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$EVENT_RESPONSE_BODY"
[ "$EVENT_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 creating event got ${EVENT_HTTP_CODE}"; exit 1; }
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_RESPONSE_BODY" | head -n 1)"
[ -n "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected event id in create-event response"; exit 1; }

# When
echo "STEP: When — register attendee for the active event"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "eventId": "${EVENT_ID}",
  "name": "John Doe",
  "email": "${ATTENDEE_EMAIL}",
  "phone": "+1-555-123-4567"
}
EOF

echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$REQUEST_BODY_FILE"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$REQUEST_BODY_FILE")"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$RESPONSE_BODY"

# Then
echo "STEP: Then — assert successful registration response"
[ "$HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${HTTP_CODE}"; exit 1; }
grep -Eq '"id":"reg_[^"]+"' "$RESPONSE_BODY" || { echo "ASSERTION_FAILED: expected generated registration id starting with reg_"; exit 1; }
grep -F "\"eventId\":\"${EVENT_ID}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected eventId ${EVENT_ID} in response body"; exit 1; }
grep -F '"name":"John Doe"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected attendee name in response body"; exit 1; }
grep -F "\"email\":\"${ATTENDEE_EMAIL}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected attendee email in response body"; exit 1; }
grep -F '"phone":"+1-555-123-4567"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected attendee phone in response body"; exit 1; }
grep -Eq '"registeredAt":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[^"]+"' "$RESPONSE_BODY" || { echo "ASSERTION_FAILED: expected registeredAt ISO timestamp in response body"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup endpoint exists; rely on isolated in-memory test data"

echo "CODEVALID_TEST_ASSERTION_OK:happy_path_successful_registration"
