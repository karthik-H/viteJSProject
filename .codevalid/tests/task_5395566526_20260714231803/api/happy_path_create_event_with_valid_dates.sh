#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)_$$"
EVENT_TITLE="Tech Conference 2025 ${CASE_SUFFIX}"
EVENT_DESCRIPTION="Annual technology summit"
EVENT_START_DATE="2025-03-01"
EVENT_END_DATE="2025-03-03"
EVENT_LOCATION="Convention Center Hall A"
CREATE_BODY_FILE="/tmp/happy_path_create_event_with_valid_dates_create_body_${CASE_SUFFIX}.json"
CREATE_RESPONSE_BODY="/tmp/happy_path_create_event_with_valid_dates_create_response_${CASE_SUFFIX}.json"
CREATE_RESPONSE_HEADERS="/tmp/happy_path_create_event_with_valid_dates_create_headers_${CASE_SUFFIX}.txt"
LIST_RESPONSE_BODY="/tmp/happy_path_create_event_with_valid_dates_list_response_${CASE_SUFFIX}.json"
LIST_RESPONSE_HEADERS="/tmp/happy_path_create_event_with_valid_dates_list_headers_${CASE_SUFFIX}.txt"
CREATED_EVENT_ID=""
cleanup_files() {
  rm -f "$CREATE_BODY_FILE" "$CREATE_RESPONSE_BODY" "$CREATE_RESPONSE_HEADERS" "$LIST_RESPONSE_BODY" "$LIST_RESPONSE_HEADERS"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare unique event payload for valid event creation"
echo "PREREQ: unique event title prepared to keep test self-contained"
cat > "$CREATE_BODY_FILE" <<EOF
{
  "title": "$EVENT_TITLE",
  "description": "$EVENT_DESCRIPTION",
  "startDate": "$EVENT_START_DATE",
  "endDate": "$EVENT_END_DATE",
  "location": "$EVENT_LOCATION"
}
EOF

# When
echo "STEP: When — create a new event with valid required fields"
echo 'REQUEST_HEADERS: Content-Type: application/json'
echo 'REQUEST_BODY:'
cat "$CREATE_BODY_FILE"
create_status="$(curl -sS -o "$CREATE_RESPONSE_BODY" -D "$CREATE_RESPONSE_HEADERS" -w '%{http_code}' -X POST "$BASE_URL/api/events" -H 'Content-Type: application/json' --data @"$CREATE_BODY_FILE")"
echo "RESPONSE_STATUS: $create_status"
echo 'RESPONSE_HEADERS:'
cat "$CREATE_RESPONSE_HEADERS"
echo 'RESPONSE_BODY:'
cat "$CREATE_RESPONSE_BODY"
CREATED_EVENT_ID="$(jq -r '.id // empty' "$CREATE_RESPONSE_BODY")"

# Then
echo "STEP: Then — assert the event is created and returned by the dashboard list"
[ "$create_status" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${create_status}"; exit 1; }
[ -n "$CREATED_EVENT_ID" ] || { echo "ASSERTION_FAILED: expected created event id in response"; exit 1; }
[ "$CREATED_EVENT_ID" != "null" ] || { echo "ASSERTION_FAILED: expected created event id to be non-null"; exit 1; }
response_title="$(jq -r '.title' "$CREATE_RESPONSE_BODY")"
[ "$response_title" = "$EVENT_TITLE" ] || { echo "ASSERTION_FAILED: expected response title ${EVENT_TITLE} got ${response_title}"; exit 1; }
response_description="$(jq -r '.description' "$CREATE_RESPONSE_BODY")"
[ "$response_description" = "$EVENT_DESCRIPTION" ] || { echo "ASSERTION_FAILED: expected response description ${EVENT_DESCRIPTION} got ${response_description}"; exit 1; }
response_start_date="$(jq -r '.startDate' "$CREATE_RESPONSE_BODY")"
[ "$response_start_date" = "$EVENT_START_DATE" ] || { echo "ASSERTION_FAILED: expected response startDate ${EVENT_START_DATE} got ${response_start_date}"; exit 1; }
response_end_date="$(jq -r '.endDate' "$CREATE_RESPONSE_BODY")"
[ "$response_end_date" = "$EVENT_END_DATE" ] || { echo "ASSERTION_FAILED: expected response endDate ${EVENT_END_DATE} got ${response_end_date}"; exit 1; }
response_location="$(jq -r '.location' "$CREATE_RESPONSE_BODY")"
[ "$response_location" = "$EVENT_LOCATION" ] || { echo "ASSERTION_FAILED: expected response location ${EVENT_LOCATION} got ${response_location}"; exit 1; }
response_registration_count="$(jq -r '.registrationCount' "$CREATE_RESPONSE_BODY")"
[ "$response_registration_count" = "0" ] || { echo "ASSERTION_FAILED: expected registrationCount 0 got ${response_registration_count}"; exit 1; }

echo "STEP: Then — verify the created event is visible from the dashboard events API"
echo 'REQUEST_HEADERS: Accept: application/json'
echo 'REQUEST_BODY: <empty>'
list_status="$(curl -sS -o "$LIST_RESPONSE_BODY" -D "$LIST_RESPONSE_HEADERS" -w '%{http_code}' "$BASE_URL/api/events")"
echo "RESPONSE_STATUS: $list_status"
echo 'RESPONSE_HEADERS:'
cat "$LIST_RESPONSE_HEADERS"
echo 'RESPONSE_BODY:'
cat "$LIST_RESPONSE_BODY"
[ "$list_status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 from events list got ${list_status}"; exit 1; }
jq -e --arg id "$CREATED_EVENT_ID" --arg title "$EVENT_TITLE" --arg startDate "$EVENT_START_DATE" --arg endDate "$EVENT_END_DATE" --arg location "$EVENT_LOCATION" '.[] | select(.id == $id and .title == $title and .startDate == $startDate and .endDate == $endDate and .location == $location and .registrationCount == 0)' "$LIST_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected created event to appear in GET /api/events with registrationCount 0"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for the self-contained test"
cleanup_files

echo "CODEVALID_TEST_ASSERTION_OK:happy_path_create_event_with_valid_dates"
