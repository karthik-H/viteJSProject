#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)_$$"
TODAY_UTC="$(date -u +%Y-%m-%d)"
EVENT_TITLE="Summer Festival ${CASE_SUFFIX}"
EVENT_DESCRIPTION="Annual summer event"
EVENT_START_DATE="$TODAY_UTC"
EVENT_END_DATE="$TODAY_UTC"
EVENT_LOCATION="City Plaza"
ATTENDEE_NAME="Within Range Attendee ${CASE_SUFFIX}"
ATTENDEE_EMAIL="within-range-${CASE_SUFFIX}@example.com"
ATTENDEE_PHONE="555010${CASE_SUFFIX#*_}"
CREATE_BODY_FILE="/tmp/boundary_case_current_date_within_event_range_create_body_${CASE_SUFFIX}.json"
CREATE_RESPONSE_BODY="/tmp/boundary_case_current_date_within_event_range_create_response_${CASE_SUFFIX}.json"
CREATE_RESPONSE_HEADERS="/tmp/boundary_case_current_date_within_event_range_create_headers_${CASE_SUFFIX}.txt"
REGISTER_BODY_FILE="/tmp/boundary_case_current_date_within_event_range_register_body_${CASE_SUFFIX}.json"
REGISTER_RESPONSE_BODY="/tmp/boundary_case_current_date_within_event_range_register_response_${CASE_SUFFIX}.json"
REGISTER_RESPONSE_HEADERS="/tmp/boundary_case_current_date_within_event_range_register_headers_${CASE_SUFFIX}.txt"
EVENT_ID=""
cleanup_files() {
  rm -f "$CREATE_BODY_FILE" "$CREATE_RESPONSE_BODY" "$CREATE_RESPONSE_HEADERS" "$REGISTER_BODY_FILE" "$REGISTER_RESPONSE_BODY" "$REGISTER_RESPONSE_HEADERS"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — create an event whose dates include the current UTC date"
echo "PREREQ: using today's date for both startDate and endDate so registration is in-range"
cat > "$CREATE_BODY_FILE" <<EOF
{
  "title": "$EVENT_TITLE",
  "description": "$EVENT_DESCRIPTION",
  "startDate": "$EVENT_START_DATE",
  "endDate": "$EVENT_END_DATE",
  "location": "$EVENT_LOCATION"
}
EOF
echo 'REQUEST_HEADERS: Content-Type: application/json'
echo 'REQUEST_BODY:'
cat "$CREATE_BODY_FILE"
create_status="$(curl -sS -o "$CREATE_RESPONSE_BODY" -D "$CREATE_RESPONSE_HEADERS" -w '%{http_code}' -X POST "$BASE_URL/api/events" -H 'Content-Type: application/json' --data @"$CREATE_BODY_FILE")"
echo "RESPONSE_STATUS: $create_status"
echo 'RESPONSE_HEADERS:'
cat "$CREATE_RESPONSE_HEADERS"
echo 'RESPONSE_BODY:'
cat "$CREATE_RESPONSE_BODY"
[ "$create_status" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 creating event got ${create_status}"; exit 1; }
EVENT_ID="$(jq -r '.id // empty' "$CREATE_RESPONSE_BODY")"
[ -n "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected event id after creation"; exit 1; }

# When
echo "STEP: When — register an attendee while current date is within the event range"
echo "PREREQ: building registration request body for the created event"
cat > "$REGISTER_BODY_FILE" <<EOF
{
  "eventId": "$EVENT_ID",
  "name": "$ATTENDEE_NAME",
  "email": "$ATTENDEE_EMAIL",
  "phone": "$ATTENDEE_PHONE"
}
EOF
echo 'REQUEST_HEADERS: Content-Type: application/json'
echo 'REQUEST_BODY:'
cat "$REGISTER_BODY_FILE"
register_status="$(curl -sS -o "$REGISTER_RESPONSE_BODY" -D "$REGISTER_RESPONSE_HEADERS" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" -H 'Content-Type: application/json' --data @"$REGISTER_BODY_FILE")"
echo "RESPONSE_STATUS: $register_status"
echo 'RESPONSE_HEADERS:'
cat "$REGISTER_RESPONSE_HEADERS"
echo 'RESPONSE_BODY:'
cat "$REGISTER_RESPONSE_BODY"

# Then
echo "STEP: Then — assert registration succeeds because current date is within the event window"
[ "$register_status" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${register_status}"; exit 1; }
returned_event_id="$(jq -r '.eventId' "$REGISTER_RESPONSE_BODY")"
[ "$returned_event_id" = "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected registration eventId ${EVENT_ID} got ${returned_event_id}"; exit 1; }
returned_name="$(jq -r '.name' "$REGISTER_RESPONSE_BODY")"
[ "$returned_name" = "$ATTENDEE_NAME" ] || { echo "ASSERTION_FAILED: expected registration name ${ATTENDEE_NAME} got ${returned_name}"; exit 1; }
returned_email="$(jq -r '.email' "$REGISTER_RESPONSE_BODY")"
[ "$returned_email" = "$ATTENDEE_EMAIL" ] || { echo "ASSERTION_FAILED: expected registration email ${ATTENDEE_EMAIL} got ${returned_email}"; exit 1; }
returned_phone="$(jq -r '.phone' "$REGISTER_RESPONSE_BODY")"
[ "$returned_phone" = "$ATTENDEE_PHONE" ] || { echo "ASSERTION_FAILED: expected registration phone ${ATTENDEE_PHONE} got ${returned_phone}"; exit 1; }
registered_at="$(jq -r '.registeredAt // empty' "$REGISTER_RESPONSE_BODY")"
[ -n "$registered_at" ] || { echo "ASSERTION_FAILED: expected registeredAt to be present"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files created by the test"
cleanup_files

echo "CODEVALID_TEST_ASSERTION_OK:boundary_case_current_date_within_event_range"
