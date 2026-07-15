#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/create_event_success_happy_path_${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
REQUEST_BODY_FILE="$TMP_DIR/request_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.txt"
LIST_HEADERS="$TMP_DIR/list_headers.txt"
LIST_BODY="$TMP_DIR/list_body.txt"
EVENT_TITLE="Tech Conference 2025 ${CASE_SUFFIX}"
EVENT_ID=""
cleanup_tmp() {
  rm -rf "$TMP_DIR"
}
trap cleanup_tmp EXIT

# Given
echo "STEP: Given — prepare unique valid event payload"
echo "PREREQ: building request body for a valid event create request"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "title": "${EVENT_TITLE}",
  "description": "Annual tech meetup",
  "startDate": "2025-06-01",
  "endDate": "2025-06-03",
  "location": "Convention Center"
}
EOF

echo "PREREQ: request body prepared at $REQUEST_BODY_FILE"

# When
echo "STEP: When — create event via POST /api/events"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data @"$REQUEST_BODY_FILE")"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"

# Then
echo "STEP: Then — assert created event response and events listing"
[ "$HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${HTTP_CODE}"; exit 1; }
grep -F '"title":"'"$EVENT_TITLE"'"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain created event title ${EVENT_TITLE}"; exit 1; }
grep -F '"description":"Annual tech meetup"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain description"; exit 1; }
grep -F '"startDate":"2025-06-01"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain startDate 2025-06-01"; exit 1; }
grep -F '"endDate":"2025-06-03"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain endDate 2025-06-03"; exit 1; }
grep -F '"location":"Convention Center"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain location Convention Center"; exit 1; }
grep -F '"registrationCount":0' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain registrationCount 0"; exit 1; }
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$RESPONSE_BODY" | head -1)"
[ -n "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected response body to contain non-empty id"; exit 1; }

echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY:"
echo "<empty>"
LIST_CODE="$(curl -sS -D "$LIST_HEADERS" -o "$LIST_BODY" -w '%{http_code}' "$BASE_URL/api/events")"
echo "RESPONSE_STATUS: $LIST_CODE"
echo "RESPONSE_HEADERS:"
cat "$LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_BODY"
[ "$LIST_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${LIST_CODE} from GET /api/events"; exit 1; }
grep -F '"id":"'"$EVENT_ID"'"' "$LIST_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected events list to contain created event id ${EVENT_ID}"; exit 1; }
grep -F '"title":"'"$EVENT_TITLE"'"' "$LIST_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected events list to contain created event title ${EVENT_TITLE}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup endpoint exists for in-memory events"
echo "PREREQ: unique event title keeps this test self-contained in isolated runs"

echo "CODEVALID_TEST_ASSERTION_OK:create_event_success_happy_path"
