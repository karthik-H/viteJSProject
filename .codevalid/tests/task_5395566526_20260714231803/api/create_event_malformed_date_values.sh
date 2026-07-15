#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/create_event_malformed_date_values_${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
REQUEST_BODY_FILE="$TMP_DIR/request_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.txt"
LIST_HEADERS="$TMP_DIR/list_headers.txt"
LIST_BODY="$TMP_DIR/list_body.txt"
EVENT_TITLE="Bad Date Event ${CASE_SUFFIX}"
cleanup_tmp() {
  rm -rf "$TMP_DIR"
}
trap cleanup_tmp EXIT

# Given
echo "STEP: Given — prepare malformed date event payload"
echo "PREREQ: building request body with startDate not-a-date"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "title": "${EVENT_TITLE}",
  "startDate": "not-a-date",
  "endDate": "2025-11-01",
  "location": "Venue X"
}
EOF

# When
echo "STEP: When — submit POST /api/events with malformed date values"
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
echo "STEP: Then — assert malformed date payload is rejected and not listed"
[ "$HTTP_CODE" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${HTTP_CODE}"; exit 1; }
grep -Ei 'required|date|invalid|Start date must be before or equal to the end date' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected validation-related error message for malformed date values"; exit 1; }

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
if grep -F '"title":"'"$EVENT_TITLE"'"' "$LIST_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected malformed date event not to be added to events list"
  exit 1
fi

# Cleanup
echo "STEP: Cleanup — no cleanup required because request should be rejected"

echo "CODEVALID_TEST_ASSERTION_OK:create_event_malformed_date_values"
