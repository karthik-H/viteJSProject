#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TODAY="$(date -u +%F)"
EVENT_ONE_TITLE="Primary Event ${CASE_SUFFIX}"
EVENT_TWO_TITLE="Secondary Event ${CASE_SUFFIX}"
SHARED_EMAIL="shared.email.${CASE_SUFFIX}@example.com"
TMP_DIR="$(mktemp -d)"
EVENT_ONE_REQUEST_BODY="$TMP_DIR/event_one_request.json"
EVENT_ONE_RESPONSE_HEADERS="$TMP_DIR/event_one_response_headers.txt"
EVENT_ONE_RESPONSE_BODY="$TMP_DIR/event_one_response_body.json"
EVENT_TWO_REQUEST_BODY="$TMP_DIR/event_two_request.json"
EVENT_TWO_RESPONSE_HEADERS="$TMP_DIR/event_two_response_headers.txt"
EVENT_TWO_RESPONSE_BODY="$TMP_DIR/event_two_response_body.json"
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
echo "STEP: Given — create two active events and register the shared email only on the first event"
cat > "$EVENT_ONE_REQUEST_BODY" <<EOF
{
  "title": "${EVENT_ONE_TITLE}",
  "description": "First event for shared email",
  "startDate": "${TODAY}",
  "endDate": "${TODAY}",
  "location": "Hall A"
}
EOF

echo "PREREQ: creating first active event"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$EVENT_ONE_REQUEST_BODY"
EVENT_ONE_HTTP_CODE="$(curl -sS -D "$EVENT_ONE_RESPONSE_HEADERS" -o "$EVENT_ONE_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data @"$EVENT_ONE_REQUEST_BODY")"
echo "RESPONSE_STATUS: $EVENT_ONE_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$EVENT_ONE_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$EVENT_ONE_RESPONSE_BODY"
[ "$EVENT_ONE_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 creating first event got ${EVENT_ONE_HTTP_CODE}"; exit 1; }
EVENT_ONE_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_ONE_RESPONSE_BODY" | head -n 1)"
[ -n "$EVENT_ONE_ID" ] || { echo "ASSERTION_FAILED: expected first event id in response"; exit 1; }

cat > "$EVENT_TWO_REQUEST_BODY" <<EOF
{
  "title": "${EVENT_TWO_TITLE}",
  "description": "Second event for shared email",
  "startDate": "${TODAY}",
  "endDate": "${TODAY}",
  "location": "Hall B"
}
EOF

echo "PREREQ: creating second active event"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$EVENT_TWO_REQUEST_BODY"
EVENT_TWO_HTTP_CODE="$(curl -sS -D "$EVENT_TWO_RESPONSE_HEADERS" -o "$EVENT_TWO_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data @"$EVENT_TWO_REQUEST_BODY")"
echo "RESPONSE_STATUS: $EVENT_TWO_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$EVENT_TWO_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$EVENT_TWO_RESPONSE_BODY"
[ "$EVENT_TWO_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 creating second event got ${EVENT_TWO_HTTP_CODE}"; exit 1; }
EVENT_TWO_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_TWO_RESPONSE_BODY" | head -n 1)"
[ -n "$EVENT_TWO_ID" ] || { echo "ASSERTION_FAILED: expected second event id in response"; exit 1; }

cat > "$INITIAL_REG_REQUEST_BODY" <<EOF
{
  "eventId": "${EVENT_ONE_ID}",
  "name": "Existing Shared Email",
  "email": "${SHARED_EMAIL}",
  "phone": "+1-555-444-5555"
}
EOF

echo "PREREQ: creating shared-email registration on the first event"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$INITIAL_REG_REQUEST_BODY"
INITIAL_REG_HTTP_CODE="$(curl -sS -D "$INITIAL_REG_RESPONSE_HEADERS" -o "$INITIAL_REG_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$INITIAL_REG_REQUEST_BODY")"
echo "RESPONSE_STATUS: $INITIAL_REG_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$INITIAL_REG_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$INITIAL_REG_RESPONSE_BODY"
[ "$INITIAL_REG_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 creating initial shared-email registration got ${INITIAL_REG_HTTP_CODE}"; exit 1; }

# When
echo "STEP: When — register the same email for a different event"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "eventId": "${EVENT_TWO_ID}",
  "name": "Shared Email User",
  "email": "${SHARED_EMAIL}",
  "phone": "+1-555-555-6666"
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
echo "STEP: Then — assert duplicate-email check is scoped per event"
[ "$HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${HTTP_CODE}"; exit 1; }
grep -Eq '"id":"reg_[^"]+"' "$RESPONSE_BODY" || { echo "ASSERTION_FAILED: expected generated registration id starting with reg_"; exit 1; }
grep -F "\"eventId\":\"${EVENT_TWO_ID}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected eventId ${EVENT_TWO_ID} in response body"; exit 1; }
grep -F "\"email\":\"${SHARED_EMAIL}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected shared email in response body"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup endpoint exists; rely on isolated in-memory test data"

echo "CODEVALID_TEST_ASSERTION_OK:duplicate_email_different_event"
