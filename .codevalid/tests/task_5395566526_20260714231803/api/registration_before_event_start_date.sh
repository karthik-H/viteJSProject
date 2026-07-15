#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
NEXT_YEAR="$(date -u +%Y | awk '{print $1 + 1}')"
START_DATE="${NEXT_YEAR}-01-01"
END_DATE="${NEXT_YEAR}-01-15"
EVENT_TITLE="Future Event ${CASE_SUFFIX}"
ATTENDEE_EMAIL="early.bird.${CASE_SUFFIX}@example.com"
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
echo "STEP: Given — create an event whose registration window has not opened yet"
cat > "$EVENT_REQUEST_BODY" <<EOF
{
  "title": "${EVENT_TITLE}",
  "description": "Future registration event",
  "startDate": "${START_DATE}",
  "endDate": "${END_DATE}",
  "location": "Future Hall"
}
EOF

echo "PREREQ: creating future event via ${BASE_URL}/api/events"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$EVENT_REQUEST_BODY"
EVENT_HTTP_CODE="$(curl -sS -D "$EVENT_RESPONSE_HEADERS" -o "$EVENT_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data @"$EVENT_REQUEST_BODY")"
echo "RESPONSE_STATUS: $EVENT_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$EVENT_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$EVENT_RESPONSE_BODY"
[ "$EVENT_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 creating future event got ${EVENT_HTTP_CODE}"; exit 1; }
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_RESPONSE_BODY" | head -n 1)"
[ -n "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected event id in create-event response"; exit 1; }

# When
echo "STEP: When — attempt registration before event start date"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "eventId": "${EVENT_ID}",
  "name": "Early Bird",
  "email": "${ATTENDEE_EMAIL}",
  "phone": "+1-555-999-0000"
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
echo "STEP: Then — assert registration is rejected because the event has not started"
[ "$HTTP_CODE" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${HTTP_CODE}"; exit 1; }
EXPECTED_MESSAGE="Registration has not opened yet. Registration opens on ${START_DATE}."
grep -F "$EXPECTED_MESSAGE" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected message '${EXPECTED_MESSAGE}'"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup endpoint exists; rely on isolated in-memory test data"

echo "CODEVALID_TEST_ASSERTION_OK:registration_before_event_start_date"
