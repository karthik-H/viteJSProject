#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TODAY="$(date -u +%F)"
EVENT_TITLE="Case Insensitive Event ${CASE_SUFFIX}"
LOWER_EMAIL="test.user.${CASE_SUFFIX}@example.com"
UPPER_EMAIL="TEST.USER.${CASE_SUFFIX}@EXAMPLE.COM"
TMP_DIR="$(mktemp -d)"
EVENT_REQUEST_BODY="$TMP_DIR/event_request.json"
EVENT_RESPONSE_HEADERS="$TMP_DIR/event_response_headers.txt"
EVENT_RESPONSE_BODY="$TMP_DIR/event_response_body.json"
INITIAL_REG_REQUEST_BODY="$TMP_DIR/initial_registration_request.json"
INITIAL_REG_RESPONSE_HEADERS="$TMP_DIR/initial_registration_response_headers.txt"
INITIAL_REG_RESPONSE_BODY="$TMP_DIR/initial_registration_response_body.json"
REQUEST_BODY_FILE="$TMP_DIR/request_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"

cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — create an active event and register a lowercase email"
cat > "$EVENT_REQUEST_BODY" <<EOF
{
  "title": "${EVENT_TITLE}",
  "description": "Case-insensitive duplicate email event",
  "startDate": "${TODAY}",
  "endDate": "${TODAY}",
  "location": "Case Hall"
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

cat > "$INITIAL_REG_REQUEST_BODY" <<EOF
{
  "eventId": "${EVENT_ID}",
  "name": "Lowercase Email User",
  "email": "${LOWER_EMAIL}",
  "phone": "+1-555-666-7777"
}
EOF

echo "PREREQ: creating initial lowercase-email registration"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$INITIAL_REG_REQUEST_BODY"
INITIAL_REG_HTTP_CODE="$(curl -sS -D "$INITIAL_REG_RESPONSE_HEADERS" -o "$INITIAL_REG_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$INITIAL_REG_REQUEST_BODY")"
echo "RESPONSE_STATUS: $INITIAL_REG_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$INITIAL_REG_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$INITIAL_REG_RESPONSE_BODY"
[ "$INITIAL_REG_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 creating initial registration got ${INITIAL_REG_HTTP_CODE}"; exit 1; }

# When
echo "STEP: When — attempt registration with the same email in different case"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "eventId": "${EVENT_ID}",
  "name": "Case Different",
  "email": "${UPPER_EMAIL}",
  "phone": "+1-555-777-8888"
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
echo "STEP: Then — assert duplicate email detection is case-insensitive"
[ "$HTTP_CODE" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${HTTP_CODE}"; exit 1; }
EXPECTED_MESSAGE='This email is already registered for this event.'
grep -F "$EXPECTED_MESSAGE" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected message '${EXPECTED_MESSAGE}'"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup endpoint exists; rely on isolated in-memory test data"

echo "CODEVALID_TEST_ASSERTION_OK:case_insensitive_duplicate_email"
