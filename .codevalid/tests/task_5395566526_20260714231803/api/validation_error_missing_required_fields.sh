#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)_$$"
REQUEST_BODY_FILE="/tmp/validation_error_missing_required_fields_body_${CASE_SUFFIX}.json"
RESPONSE_BODY_FILE="/tmp/validation_error_missing_required_fields_response_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/validation_error_missing_required_fields_headers_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$REQUEST_BODY_FILE" "$RESPONSE_BODY_FILE" "$RESPONSE_HEADERS_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare an incomplete event creation payload"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "title": "Incomplete Event ${CASE_SUFFIX}",
  "startDate": "2025-04-10"
}
EOF
echo "PREREQ: incomplete payload omits endDate and location as required by the validation scenario"

# When
echo "STEP: When — submit event creation with missing required fields"
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
echo "STEP: Then — assert the API rejects the request with the required validation message"
[ "$status_code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${status_code}"; exit 1; }
actual_message="$(jq -r '.message' "$RESPONSE_BODY_FILE")"
[ "$actual_message" = "Title, start date, end date, and location are required." ] || { echo "ASSERTION_FAILED: expected validation message for missing required event fields got ${actual_message}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for the stateless validation test"
cleanup_files

echo "CODEVALID_TEST_ASSERTION_OK:validation_error_missing_required_fields"
