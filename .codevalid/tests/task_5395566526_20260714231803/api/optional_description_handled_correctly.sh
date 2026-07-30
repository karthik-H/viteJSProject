#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)_$$"
EVENT_TITLE="Minimal Event ${CASE_SUFFIX}"
EVENT_START_DATE="2025-07-01"
EVENT_END_DATE="2025-07-02"
EVENT_LOCATION="Outdoor Park"
REQUEST_BODY_FILE="/tmp/optional_description_handled_correctly_body_${CASE_SUFFIX}.json"
RESPONSE_BODY_FILE="/tmp/optional_description_handled_correctly_response_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/optional_description_handled_correctly_headers_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$REQUEST_BODY_FILE" "$RESPONSE_BODY_FILE" "$RESPONSE_HEADERS_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare an event creation payload without a description field"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "title": "$EVENT_TITLE",
  "startDate": "$EVENT_START_DATE",
  "endDate": "$EVENT_END_DATE",
  "location": "$EVENT_LOCATION"
}
EOF
echo "PREREQ: payload omits description to verify the API defaults it to an empty string"

# When
echo "STEP: When — create an event without description"
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
echo "STEP: Then — assert the response sets description to an empty string and registrationCount to zero"
[ "$status_code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${status_code}"; exit 1; }
response_description="$(jq -r '.description' "$RESPONSE_BODY_FILE")"
[ "$response_description" = "" ] || { echo "ASSERTION_FAILED: expected empty description got ${response_description}"; exit 1; }
response_registration_count="$(jq -r '.registrationCount' "$RESPONSE_BODY_FILE")"
[ "$response_registration_count" = "0" ] || { echo "ASSERTION_FAILED: expected registrationCount 0 got ${response_registration_count}"; exit 1; }
response_title="$(jq -r '.title' "$RESPONSE_BODY_FILE")"
[ "$response_title" = "$EVENT_TITLE" ] || { echo "ASSERTION_FAILED: expected response title ${EVENT_TITLE} got ${response_title}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for the self-contained event creation test"
cleanup_files

echo "CODEVALID_TEST_ASSERTION_OK:optional_description_handled_correctly"
