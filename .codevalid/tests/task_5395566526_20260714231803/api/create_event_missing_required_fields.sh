#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="/tmp/create_event_missing_required_fields_${CASE_SUFFIX}"
mkdir -p "$TMP_DIR"
REQUEST_BODY_FILE="$TMP_DIR/request_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.txt"
cleanup_tmp() {
  rm -rf "$TMP_DIR"
}
trap cleanup_tmp EXIT

# Given
echo "STEP: Given — prepare incomplete event payload"
echo "PREREQ: building request body without endDate and location"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "title": "Incomplete Event ${CASE_SUFFIX}",
  "startDate": "2025-07-01"
}
EOF

# When
echo "STEP: When — submit POST /api/events missing required fields"
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
echo "STEP: Then — assert 400 validation error for required fields"
[ "$HTTP_CODE" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${HTTP_CODE}"; exit 1; }
grep -F 'Title, start date, end date, and location are required.' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected required-fields validation message"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup required because request was rejected"

echo "CODEVALID_TEST_ASSERTION_OK:create_event_missing_required_fields"
