#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
EVENT_ONE_HEADERS="$TMP_DIR/event_one_headers.txt"
EVENT_ONE_BODY="$TMP_DIR/event_one_body.json"
EVENT_TWO_HEADERS="$TMP_DIR/event_two_headers.txt"
EVENT_TWO_BODY="$TMP_DIR/event_two_body.json"
EVENT_THREE_HEADERS="$TMP_DIR/event_three_headers.txt"
EVENT_THREE_BODY="$TMP_DIR/event_three_body.json"
REG_HEADERS="$TMP_DIR/reg_headers.txt"
REG_BODY="$TMP_DIR/reg_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"

cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

create_event() {
  out_headers="$1"
  out_body="$2"
  title="$3"
  start_date="$4"
  end_date="$5"
  location="$6"
  request_file="$TMP_DIR/request_$(basename "$out_body")"

  echo "PREREQ: creating event ${title}"
  cat > "$request_file" <<EOF
{"title":"${title}","description":"dashboard retrieval test","startDate":"${start_date}","endDate":"${end_date}","location":"${location}"}
EOF
  echo "REQUEST_HEADERS: Content-Type: application/json"
  echo "REQUEST_BODY:"
  cat "$request_file"
  code="$(curl -sS -D "$out_headers" -o "$out_body" -w '%{http_code}' \
    -X POST "$BASE_URL/api/events" \
    -H 'Content-Type: application/json' \
    --data @"$request_file")"
  echo "RESPONSE_STATUS: $code"
  echo "RESPONSE_HEADERS:"
  cat "$out_headers"
  echo "RESPONSE_BODY:"
  cat "$out_body"
  [ "$code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${code} while creating event"; exit 1; }
}

create_registration() {
  out_headers="$1"
  out_body="$2"
  event_id="$3"
  attendee_name="$4"
  attendee_email="$5"
  attendee_phone="$6"
  request_file="$TMP_DIR/request_reg_$(basename "$out_body")"

  echo "PREREQ: registering attendee ${attendee_email} for ${event_id}"
  cat > "$request_file" <<EOF
{"eventId":"${event_id}","name":"${attendee_name}","email":"${attendee_email}","phone":"${attendee_phone}"}
EOF
  echo "REQUEST_HEADERS: Content-Type: application/json"
  echo "REQUEST_BODY:"
  cat "$request_file"
  code="$(curl -sS -D "$out_headers" -o "$out_body" -w '%{http_code}' \
    -X POST "$BASE_URL/api/registrations" \
    -H 'Content-Type: application/json' \
    --data @"$request_file")"
  echo "RESPONSE_STATUS: $code"
  echo "RESPONSE_HEADERS:"
  cat "$out_headers"
  echo "RESPONSE_BODY:"
  cat "$out_body"
  [ "$code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${code} while creating registration"; exit 1; }
}

TODAY="$(date -u +%F)"
YESTERDAY="$(date -u -d "$TODAY - 1 day" +%F 2>/dev/null || date -u -v-1d +%F)"
TOMORROW="$(date -u -d "$TODAY + 1 day" +%F 2>/dev/null || date -u -v+1d +%F)"
DAY_AFTER_TOMORROW="$(date -u -d "$TODAY + 2 day" +%F 2>/dev/null || date -u -v+2d +%F)"

# Given
 echo "STEP: Given — create 3 events and at least one registration for dashboard retrieval"
create_event "$EVENT_ONE_HEADERS" "$EVENT_ONE_BODY" "Tech Conference ${CASE_SUFFIX}" "$TODAY" "$TOMORROW" "Hall A ${CASE_SUFFIX}"
create_event "$EVENT_TWO_HEADERS" "$EVENT_TWO_BODY" "Workshop Series ${CASE_SUFFIX}" "$YESTERDAY" "$TODAY" "Hall B ${CASE_SUFFIX}"
create_event "$EVENT_THREE_HEADERS" "$EVENT_THREE_BODY" "Planning Meetup ${CASE_SUFFIX}" "$TOMORROW" "$DAY_AFTER_TOMORROW" "Hall C ${CASE_SUFFIX}"

EVENT_ID_ONE="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_ONE_BODY" | head -1)"
EVENT_ID_TWO="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_TWO_BODY" | head -1)"
EVENT_ID_THREE="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_THREE_BODY" | head -1)"
[ -n "$EVENT_ID_ONE" ] || { echo "ASSERTION_FAILED: expected first event id"; exit 1; }
[ -n "$EVENT_ID_TWO" ] || { echo "ASSERTION_FAILED: expected second event id"; exit 1; }
[ -n "$EVENT_ID_THREE" ] || { echo "ASSERTION_FAILED: expected third event id"; exit 1; }

create_registration "$REG_HEADERS" "$REG_BODY" "$EVENT_ID_ONE" "Alice ${CASE_SUFFIX}" "alice-${CASE_SUFFIX}@example.com" "+1-555-1001"

# When
 echo "STEP: When — fetch events list from dashboard API"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -X GET "$BASE_URL/api/events" \
  -H 'Accept: application/json')"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"

# Then
 echo "STEP: Then — assert HTTP 200 and event list structure"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -qi 'content-type: application/json' "$RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected JSON content type"; exit 1; }
grep -q '^\[' "$RESPONSE_BODY" || { echo "ASSERTION_FAILED: expected response body to be a JSON array"; exit 1; }
grep -F "\"id\":\"${EVENT_ID_ONE}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected first created event in response"; exit 1; }
grep -F "\"id\":\"${EVENT_ID_TWO}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected second created event in response"; exit 1; }
grep -F '"title"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected title field in response"; exit 1; }
grep -F '"startDate"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected startDate field in response"; exit 1; }
grep -F '"endDate"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected endDate field in response"; exit 1; }
grep -F '"registrationCount"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount field in response"; exit 1; }
grep -F '"registrationCount":1' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount 1 in response"; exit 1; }

# Cleanup
 echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events and registrations"

echo "CODEVALID_TEST_ASSERTION_OK:get_events_list_success"
