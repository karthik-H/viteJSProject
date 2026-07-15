#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/create_event_optional_description_default_${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
REQUEST_BODY_FILE="$TMP_DIR/request_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.txt"
EVENT_TITLE="Minimal Event ${CASE_SUFFIX}"
cleanup_tmp() {
  rm -rf "$TMP_DIR"
}
trap cleanup_tmp EXIT

# Given
echo "STEP: Given — prepare minimal valid event payload without description"
echo "PREREQ: building event body that omits optional description"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "title": "${EVENT_TITLE}",
  "startDate": "2025-10-01",
  "endDate": "2025-10-02",
  "location": "Park"
}
EOF

# When
echo "STEP: When — create event without description via POST /api/events"
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
echo "STEP: Then — assert description defaults to empty string"
[ "$HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${HTTP_CODE}"; exit 1; }
grep -F '"title":"'"$EVENT_TITLE"'"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain title ${EVENT_TITLE}"; exit 1; }
grep -F '"description":""' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain empty description"; exit 1; }
grep -F '"startDate":"2025-10-01"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain startDate 2025-10-01"; exit 1; }
grep -F '"endDate":"2025-10-02"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain endDate 2025-10-02"; exit 1; }
grep -F '"location":"Park"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain location Park"; exit 1; }
grep -F '"registrationCount":0' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected response body to contain registrationCount 0"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup endpoint exists for in-memory events"
echo "PREREQ: unique event title keeps test isolated"

echo "CODEVALID_TEST_ASSERTION_OK:create_event_optional_description_default"
