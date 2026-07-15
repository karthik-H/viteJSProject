#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TODAY="$(date -u +%F)"
EVENT_TITLE="Validation Event ${CASE_SUFFIX}"
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
echo "STEP: Given — create an active event for validation testing"
cat > "$EVENT_REQUEST_BODY" <<EOF
{
  "title": "${EVENT_TITLE}",
  "description": "Missing fields validation event",
  "startDate": "${TODAY}",
  "endDate": "${TODAY}",
  "location": "Validation Hall"
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
[ "$EVENT_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 creating validation event got ${EVENT_HTTP_CODE}"; exit 1; }
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_RESPONSE_BODY" | head -n 1)"
[ -n "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected event id in create-event response"; exit 1; }

# When
echo "STEP: When — submit registration missing email and phone"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "eventId": "${EVENT_ID}",
  "name": "Missing Fields User"
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
echo "STEP: Then — assert required-field validation error"
[ "$HTTP_CODE" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${HTTP_CODE}"; exit 1; }
EXPECTED_MESSAGE='Event, name, email, and phone number are required.'
grep -F "$EXPECTED_MESSAGE" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected message '${EXPECTED_MESSAGE}'"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup endpoint exists; rely on isolated in-memory test data"

echo "CODEVALID_TEST_ASSERTION_OK:missing_required_fields_validation"
