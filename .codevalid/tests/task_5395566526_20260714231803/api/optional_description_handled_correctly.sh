#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)_$$"
EVENT_TITLE="Minimal Event ${CASE_SUFFIX}"
EVENT_START_DATE="2025-07-01"
EVENT_END_DATE="2025-07-02"
EVENT_LOCATION="Outdoor Park"
CREATE_BODY_FILE="/tmp/optional_description_handled_correctly_body_${CASE_SUFFIX}.json"
CREATE_RESPONSE_BODY="/tmp/optional_description_handled_correctly_response_${CASE_SUFFIX}.json"
CREATE_RESPONSE_HEADERS="/tmp/optional_description_handled_correctly_headers_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$CREATE_BODY_FILE" "$CREATE_RESPONSE_BODY" "$CREATE_RESPONSE_HEADERS"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare event payload without description"
echo "PREREQ: unique event title prepared while omitting optional description"
cat > "$CREATE_BODY_FILE" <<EOF
{
  "title": "$EVENT_TITLE",
  "startDate": "$EVENT_START_DATE",
  "endDate": "$EVENT_END_DATE",
  "location": "$EVENT_LOCATION"
}
EOF

# When
echo "STEP: When — create event without the optional description field"
echo 'REQUEST_HEADERS: Content-Type: application/json'
echo 'REQUEST_BODY:'
cat "$CREATE_BODY_FILE"
http_code="$(curl -sS -o "$CREATE_RESPONSE_BODY" -D "$CREATE_RESPONSE_HEADERS" -w '%{http_code}' -X POST "$BASE_URL/api/events" -H 'Content-Type: application/json' --data @"$CREATE_BODY_FILE")"
echo "RESPONSE_STATUS: $http_code"
echo 'RESPONSE_HEADERS:'
cat "$CREATE_RESPONSE_HEADERS"
echo 'RESPONSE_BODY:'
cat "$CREATE_RESPONSE_BODY"

# Then
echo "STEP: Then — assert HTTP 201 and description defaults to empty string"
[ "$http_code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${http_code}"; exit 1; }
returned_title="$(jq -r '.title' "$CREATE_RESPONSE_BODY")"
[ "$returned_title" = "$EVENT_TITLE" ] || { echo "ASSERTION_FAILED: expected title ${EVENT_TITLE} got ${returned_title}"; exit 1; }
returned_description="$(jq -r '.description' "$CREATE_RESPONSE_BODY")"
[ "$returned_description" = "" ] || { echo "ASSERTION_FAILED: expected empty description got ${returned_description}"; exit 1; }
returned_registration_count="$(jq -r '.registrationCount' "$CREATE_RESPONSE_BODY")"
[ "$returned_registration_count" = "0" ] || { echo "ASSERTION_FAILED: expected registrationCount 0 got ${returned_registration_count}"; exit 1; }
returned_start_date="$(jq -r '.startDate' "$CREATE_RESPONSE_BODY")"
[ "$returned_start_date" = "$EVENT_START_DATE" ] || { echo "ASSERTION_FAILED: expected startDate ${EVENT_START_DATE} got ${returned_start_date}"; exit 1; }
returned_end_date="$(jq -r '.endDate' "$CREATE_RESPONSE_BODY")"
[ "$returned_end_date" = "$EVENT_END_DATE" ] || { echo "ASSERTION_FAILED: expected endDate ${EVENT_END_DATE} got ${returned_end_date}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files created by the test"
cleanup_files

echo "CODEVALID_TEST_ASSERTION_OK:optional_description_handled_correctly"
