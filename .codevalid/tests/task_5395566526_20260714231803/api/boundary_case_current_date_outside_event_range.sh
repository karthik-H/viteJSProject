#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)_$$"
TODAY_EPOCH="$(date -u +%s)"
TOMORROW_UTC="$(date -u -d "@$(($TODAY_EPOCH + 86400))" +%Y-%m-%d 2>/dev/null || date -u -r $(($TODAY_EPOCH + 86400)) +%Y-%m-%d)"
DAY_AFTER_TOMORROW_UTC="$(date -u -d "@$(($TODAY_EPOCH + 172800))" +%Y-%m-%d 2>/dev/null || date -u -r $(($TODAY_EPOCH + 172800)) +%Y-%m-%d)"
EVENT_TITLE="Late Autumn Workshop ${CASE_SUFFIX}"
EVENT_DESCRIPTION="Workshop after summer"
EVENT_START_DATE="$TOMORROW_UTC"
EVENT_END_DATE="$DAY_AFTER_TOMORROW_UTC"
EVENT_LOCATION="Community Hall"
ATTENDEE_NAME="Outside Range Attendee ${CASE_SUFFIX}"
ATTENDEE_EMAIL="outside-range-${CASE_SUFFIX}@example.com"
ATTENDEE_PHONE="555020${CASE_SUFFIX#*_}"
CREATE_BODY_FILE="/tmp/boundary_case_current_date_outside_event_range_create_body_${CASE_SUFFIX}.json"
CREATE_RESPONSE_BODY="/tmp/boundary_case_current_date_outside_event_range_create_response_${CASE_SUFFIX}.json"
CREATE_RESPONSE_HEADERS="/tmp/boundary_case_current_date_outside_event_range_create_headers_${CASE_SUFFIX}.txt"
REGISTER_BODY_FILE="/tmp/boundary_case_current_date_outside_event_range_register_body_${CASE_SUFFIX}.json"
REGISTER_RESPONSE_BODY="/tmp/boundary_case_current_date_outside_event_range_register_response_${CASE_SUFFIX}.json"
REGISTER_RESPONSE_HEADERS="/tmp/boundary_case_current_date_outside_event_range_register_headers_${CASE_SUFFIX}.txt"
EVENT_ID=""
cleanup_files() {
  rm -f "$CREATE_BODY_FILE" "$CREATE_RESPONSE_BODY" "$CREATE_RESPONSE_HEADERS" "$REGISTER_BODY_FILE" "$REGISTER_RESPONSE_BODY" "$REGISTER_RESPONSE_HEADERS"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — create an event whose registration window starts in the future"
echo "PREREQ: using tomorrow and the following day so current date is outside the event range"
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
echo "STEP: When — attempt attendee registration before the event start date"
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
echo "STEP: Then — assert registration is blocked because current date is outside the event range"
[ "$register_status" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${register_status}"; exit 1; }
expected_message="Registration has not opened yet. Registration opens on ${EVENT_START_DATE}."
actual_message="$(jq -r '.message' "$REGISTER_RESPONSE_BODY")"
[ "$actual_message" = "$expected_message" ] || { echo "ASSERTION_FAILED: expected message ${expected_message} got ${actual_message}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — remove temporary files created by the test"
cleanup_files

echo "CODEVALID_TEST_ASSERTION_OK:boundary_case_current_date_outside_event_range"
