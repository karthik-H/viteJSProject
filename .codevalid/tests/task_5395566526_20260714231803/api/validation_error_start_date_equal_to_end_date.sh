#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)_$$"
EVENT_TITLE="One-Day Workshop ${CASE_SUFFIX}"
EVENT_DESCRIPTION="Intensive single-day workshop"
EVENT_DATE="2025-06-15"
EVENT_LOCATION="Room 101"
CREATE_BODY_FILE="/tmp/validation_error_start_date_equal_to_end_date_create_body_${CASE_SUFFIX}.json"
CREATE_RESPONSE_BODY="/tmp/validation_error_start_date_equal_to_end_date_create_response_${CASE_SUFFIX}.json"
CREATE_RESPONSE_HEADERS="/tmp/validation_error_start_date_equal_to_end_date_create_headers_${CASE_SUFFIX}.txt"
cleanup_files() {
  rm -f "$CREATE_BODY_FILE" "$CREATE_RESPONSE_BODY" "$CREATE_RESPONSE_HEADERS"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare a single-day event payload where startDate equals endDate"
cat > "$CREATE_BODY_FILE" <<EOF
{
  "title": "$EVENT_TITLE",
  "description": "$EVENT_DESCRIPTION",
  "startDate": "$EVENT_DATE",
  "endDate": "$EVENT_DATE",
  "location": "$EVENT_LOCATION"
}
EOF
echo "PREREQ: unique single-day event payload prepared for equal-date boundary validation"

# When
echo "STEP: When — create an event whose startDate equals endDate"
echo 'REQUEST_HEADERS: Content-Type: application/json'
echo 'REQUEST_BODY:'
cat "$CREATE_BODY_FILE"
create_status="$(curl -sS -o "$CREATE_RESPONSE_BODY" -D "$CREATE_RESPONSE_HEADERS" -w '%{http_code}' -X POST "$BASE_URL/api/events" -H 'Content-Type: application/json' --data @"$CREATE_BODY_FILE")"
echo "RESPONSE_STATUS: $create_status"
echo 'RESPONSE_HEADERS:'
cat "$CREATE_RESPONSE_HEADERS"
echo 'RESPONSE_BODY:'
cat "$CREATE_RESPONSE_BODY"

# Then
echo "STEP: Then — assert single-day event creation succeeds with registrationCount zero"
[ "$create_status" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${create_status}"; exit 1; }
response_start_date="$(jq -r '.startDate' "$CREATE_RESPONSE_BODY")"
[ "$response_start_date" = "$EVENT_DATE" ] || { echo "ASSERTION_FAILED: expected startDate ${EVENT_DATE} got ${response_start_date}"; exit 1; }
response_end_date="$(jq -r '.endDate' "$CREATE_RESPONSE_BODY")"
[ "$response_end_date" = "$EVENT_DATE" ] || { echo "ASSERTION_FAILED: expected endDate ${EVENT_DATE} got ${response_end_date}"; exit 1; }
response_registration_count="$(jq -r '.registrationCount' "$CREATE_RESPONSE_BODY")"
[ "$response_registration_count" = "0" ] || { echo "ASSERTION_FAILED: expected registrationCount 0 got ${response_registration_count}"; exit 1; }
created_event_id="$(jq -r '.id // empty' "$CREATE_RESPONSE_BODY")"
[ -n "$created_event_id" ] || { echo "ASSERTION_FAILED: expected created event id for equal-date event"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for the self-contained event creation test"
cleanup_files

echo "CODEVALID_TEST_ASSERTION_OK:validation_error_start_date_equal_to_end_date"
