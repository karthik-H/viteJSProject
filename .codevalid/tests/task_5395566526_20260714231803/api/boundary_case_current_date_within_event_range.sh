#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)_$$"
EVENT_TITLE="Summer Festival ${CASE_SUFFIX}"
EVENT_DESCRIPTION="Annual summer event"
EVENT_START_DATE="2025-08-10"
EVENT_END_DATE="2025-08-12"
EVENT_LOCATION="City Plaza"
CREATE_BODY_FILE="/tmp/boundary_case_current_date_within_event_range_create_body_${CASE_SUFFIX}.json"
CREATE_RESPONSE_BODY="/tmp/boundary_case_current_date_within_event_range_create_response_${CASE_SUFFIX}.json"
CREATE_RESPONSE_HEADERS="/tmp/boundary_case_current_date_within_event_range_create_headers_${CASE_SUFFIX}.txt"
LIST_RESPONSE_BODY="/tmp/boundary_case_current_date_within_event_range_list_response_${CASE_SUFFIX}.json"
LIST_RESPONSE_HEADERS="/tmp/boundary_case_current_date_within_event_range_list_headers_${CASE_SUFFIX}.txt"
CREATED_EVENT_ID=""
cleanup_files() {
  rm -f "$CREATE_BODY_FILE" "$CREATE_RESPONSE_BODY" "$CREATE_RESPONSE_HEADERS" "$LIST_RESPONSE_BODY" "$LIST_RESPONSE_HEADERS"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare an event payload whose date range would support registration when current date is inside the window"
cat > "$CREATE_BODY_FILE" <<EOF
{
  "title": "$EVENT_TITLE",
  "description": "$EVENT_DESCRIPTION",
  "startDate": "$EVENT_START_DATE",
  "endDate": "$EVENT_END_DATE",
  "location": "$EVENT_LOCATION"
}
EOF
echo "PREREQ: valid event window prepared to support later registration eligibility checks"

# When
echo "STEP: When — create the event with an inclusive multi-day registration window"
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
echo "STEP: Then — assert the event is created with the expected dates and retrievable from the dashboard"
[ "$create_status" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${create_status}"; exit 1; }
[ -n "$CREATED_EVENT_ID" ] || { echo "ASSERTION_FAILED: expected created event id for within-range event"; exit 1; }
response_start_date="$(jq -r '.startDate' "$CREATE_RESPONSE_BODY")"
[ "$response_start_date" = "$EVENT_START_DATE" ] || { echo "ASSERTION_FAILED: expected startDate ${EVENT_START_DATE} got ${response_start_date}"; exit 1; }
response_end_date="$(jq -r '.endDate' "$CREATE_RESPONSE_BODY")"
[ "$response_end_date" = "$EVENT_END_DATE" ] || { echo "ASSERTION_FAILED: expected endDate ${EVENT_END_DATE} got ${response_end_date}"; exit 1; }

echo "STEP: Then — verify the created event appears in the dashboard events API"
echo 'REQUEST_HEADERS: Accept: application/json'
echo 'REQUEST_BODY: <empty>'
list_status="$(curl -sS -o "$LIST_RESPONSE_BODY" -D "$LIST_RESPONSE_HEADERS" -w '%{http_code}' "$BASE_URL/api/events")"
echo "RESPONSE_STATUS: $list_status"
echo 'RESPONSE_HEADERS:'
cat "$LIST_RESPONSE_HEADERS"
echo 'RESPONSE_BODY:'
cat "$LIST_RESPONSE_BODY"
[ "$list_status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 from events list got ${list_status}"; exit 1; }
jq -e --arg id "$CREATED_EVENT_ID" --arg startDate "$EVENT_START_DATE" --arg endDate "$EVENT_END_DATE" '.[] | select(.id == $id and .startDate == $startDate and .endDate == $endDate)' "$LIST_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected created within-range event to appear in GET /api/events"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files for the self-contained dashboard creation test"
cleanup_files

echo "CODEVALID_TEST_ASSERTION_OK:boundary_case_current_date_within_event_range"
