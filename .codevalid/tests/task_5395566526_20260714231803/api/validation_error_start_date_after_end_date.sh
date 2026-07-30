#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)_$$"
REQUEST_BODY_FILE="/tmp/validation_error_start_date_after_end_date_body_${CASE_SUFFIX}.json"
RESPONSE_BODY_FILE="/tmp/validation_error_start_date_after_end_date_response_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/validation_error_start_date_after_end_date_headers_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$REQUEST_BODY_FILE" "$RESPONSE_BODY_FILE" "$RESPONSE_HEADERS_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare an event payload whose startDate is later than endDate"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "title": "Invalid Date Range Event ${CASE_SUFFIX}",
  "description": "Test event for date validation",
  "startDate": "2025-05-10",
  "endDate": "2025-05-01",
  "location": "Main Auditorium"
}
EOF
echo "PREREQ: payload uses an invalid date order to trigger business validation"

# When
echo "STEP: When — submit the invalid date range event"
echo 'REQUEST_HEADERS: Content-Type: application/json'
echo 'REQUEST_BODY:'
cat "$REQUEST_BODY_FILE"
status_code="$(curl -sS -o "$RESPONSE_BODY_FILE" -D "$RESPONSE_HEADERS_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/events" -H 'Content-Type: application/json' --data @"$REQUEST_BODY_FILE")"
echo "RESPONSE_STATUS: $status_code"
echo 'RESPONSE_HEADERS:'
cat "$RESPONSE_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$RESPONSE_BODY_FILE"

# Then
echo "STEP: Then — assert the API enforces startDate before or equal to endDate"
[ "$status_code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${status_code}"; exit 1; }
actual_message="$(jq -r '.message' "$RESPONSE_BODY_FILE")"
[ "$actual_message" = "Start date must be before or equal to the end date." ] || { echo "ASSERTION_FAILED: expected invalid date range message got ${actual_message}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for the stateless validation test"
cleanup_files

echo "CODEVALID_TEST_ASSERTION_OK:validation_error_start_date_after_end_date"
