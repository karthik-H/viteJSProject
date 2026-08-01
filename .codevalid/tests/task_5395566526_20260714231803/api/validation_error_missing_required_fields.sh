#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)_$$"
CREATE_BODY_FILE="/tmp/validation_error_missing_required_fields_body_${CASE_SUFFIX}.json"
RESPONSE_BODY_FILE="/tmp/validation_error_missing_required_fields_response_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/validation_error_missing_required_fields_headers_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$CREATE_BODY_FILE" "$RESPONSE_BODY_FILE" "$RESPONSE_HEADERS_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare incomplete event payload missing required fields"
echo "PREREQ: no prior data setup required for stateless validation"
cat > "$CREATE_BODY_FILE" <<EOF
{
  "title": "Incomplete Event ${CASE_SUFFIX}",
  "startDate": "2025-04-10"
}
EOF

# When
echo "STEP: When — submit POST request with missing required fields"
echo 'REQUEST_HEADERS: Content-Type: application/json'
echo 'REQUEST_BODY:'
cat "$CREATE_BODY_FILE"
http_code="$(curl -sS -o "$RESPONSE_BODY_FILE" -D "$RESPONSE_HEADERS_FILE" -w '%{http_code}' -X POST "$BASE_URL/api/events" -H 'Content-Type: application/json' --data @"$CREATE_BODY_FILE")"
echo "RESPONSE_STATUS: $http_code"
echo 'RESPONSE_HEADERS:'
cat "$RESPONSE_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$RESPONSE_BODY_FILE"

# Then
echo "STEP: Then — assert HTTP 400 and validation message"
[ "$http_code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${http_code}"; exit 1; }
response_message="$(jq -r '.message' "$RESPONSE_BODY_FILE")"
[ "$response_message" = "Title, start date, end date, and location are required." ] || { echo "ASSERTION_FAILED: expected exact validation message got ${response_message}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for stateless negative test"
cleanup_files

echo "CODEVALID_TEST_ASSERTION_OK:validation_error_missing_required_fields"
