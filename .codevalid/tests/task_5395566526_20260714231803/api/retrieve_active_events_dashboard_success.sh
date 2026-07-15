#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
REQUEST_BODY_FILE="$TMP_DIR/request.json"
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

  echo "PREREQ: creating event ${title}"
  cat > "$REQUEST_BODY_FILE" <<EOF
{"title":"${title}","description":"dashboard retrieval test","startDate":"${start_date}","endDate":"${end_date}","location":"${location}"}
EOF
  echo "REQUEST_HEADERS: Content-Type: application/json"
  echo "REQUEST_BODY:"
  cat "$REQUEST_BODY_FILE"
  code="$(curl -sS -D "$out_headers" -o "$out_body" -w '%{http_code}' \
    -X POST "$BASE_URL/api/events" \
    -H 'Content-Type: application/json' \
    --data @"$REQUEST_BODY_FILE")"
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

  echo "PREREQ: registering attendee ${attendee_email} for ${event_id}"
  cat > "$REQUEST_BODY_FILE" <<EOF
{"eventId":"${event_id}","name":"${attendee_name}","email":"${attendee_email}","phone":"${attendee_phone}"}
EOF
  echo "REQUEST_HEADERS: Content-Type: application/json"
  echo "REQUEST_BODY:"
  cat "$REQUEST_BODY_FILE"
  code="$(curl -sS -D "$out_headers" -o "$out_body" -w '%{http_code}' \
    -X POST "$BASE_URL/api/registrations" \
    -H 'Content-Type: application/json' \
    --data @"$REQUEST_BODY_FILE")"
  echo "RESPONSE_STATUS: $code"
  echo "RESPONSE_HEADERS:"
  cat "$out_headers"
  echo "RESPONSE_BODY:"
  cat "$out_body"
  [ "$code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${code} while creating registration"; exit 1; }
}

TODAY="$(date -u +%F)"
EVENT_TWO_START="$(date -u -d "$TODAY - 1 day" +%F 2>/dev/null || date -u -v-1d +%F)"
EVENT_TWO_END="$TODAY"
EVENT_ONE_START="$TODAY"
EVENT_ONE_END="$TODAY"
EVENT_THREE_START="$(date -u -d "$TODAY + 1 day" +%F 2>/dev/null || date -u -v+1d +%F)"
EVENT_THREE_END="$(date -u -d "$TODAY + 2 day" +%F 2>/dev/null || date -u -v+2d +%F)"

EVENT_ONE_HEADERS="$TMP_DIR/event_one_headers.txt"
EVENT_ONE_BODY="$TMP_DIR/event_one_body.json"
EVENT_TWO_HEADERS="$TMP_DIR/event_two_headers.txt"
EVENT_TWO_BODY="$TMP_DIR/event_two_body.json"
EVENT_THREE_HEADERS="$TMP_DIR/event_three_headers.txt"
EVENT_THREE_BODY="$TMP_DIR/event_three_body.json"

# Given
echo "STEP: Given — create 3 events and registrations with controlled counts"
create_event "$EVENT_ONE_HEADERS" "$EVENT_ONE_BODY" "Tech Conference ${CASE_SUFFIX}" "$EVENT_ONE_START" "$EVENT_ONE_END" "Hall A"
create_event "$EVENT_TWO_HEADERS" "$EVENT_TWO_BODY" "Workshop Series ${CASE_SUFFIX}" "$EVENT_TWO_START" "$EVENT_TWO_END" "Hall B"
create_event "$EVENT_THREE_HEADERS" "$EVENT_THREE_BODY" "Annual Meeting ${CASE_SUFFIX}" "$EVENT_THREE_START" "$EVENT_THREE_END" "Hall C"

EVENT_ID_ONE="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_ONE_BODY" | head -1)"
EVENT_ID_TWO="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_TWO_BODY" | head -1)"
EVENT_ID_THREE="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_THREE_BODY" | head -1)"
[ -n "$EVENT_ID_ONE" ] || { echo "ASSERTION_FAILED: expected first event id"; exit 1; }
[ -n "$EVENT_ID_TWO" ] || { echo "ASSERTION_FAILED: expected second event id"; exit 1; }
[ -n "$EVENT_ID_THREE" ] || { echo "ASSERTION_FAILED: expected third event id"; exit 1; }

create_registration "$TMP_DIR/reg1_headers.txt" "$TMP_DIR/reg1_body.json" "$EVENT_ID_ONE" "Alice ${CASE_SUFFIX}" "alice-${CASE_SUFFIX}@example.com" "+1-555-0001"
create_registration "$TMP_DIR/reg2_headers.txt" "$TMP_DIR/reg2_body.json" "$EVENT_ID_ONE" "Bob ${CASE_SUFFIX}" "bob-${CASE_SUFFIX}@example.com" "+1-555-0002"
create_registration "$TMP_DIR/reg3_headers.txt" "$TMP_DIR/reg3_body.json" "$EVENT_ID_THREE" "Carol ${CASE_SUFFIX}" "carol-${CASE_SUFFIX}@example.com" "+1-555-0003"
create_registration "$TMP_DIR/reg4_headers.txt" "$TMP_DIR/reg4_body.json" "$EVENT_ID_THREE" "Dan ${CASE_SUFFIX}" "dan-${CASE_SUFFIX}@example.com" "+1-555-0004"
create_registration "$TMP_DIR/reg5_headers.txt" "$TMP_DIR/reg5_body.json" "$EVENT_ID_THREE" "Eve ${CASE_SUFFIX}" "eve-${CASE_SUFFIX}@example.com" "+1-555-0005"
create_registration "$TMP_DIR/reg6_headers.txt" "$TMP_DIR/reg6_body.json" "$EVENT_ID_THREE" "Frank ${CASE_SUFFIX}" "frank-${CASE_SUFFIX}@example.com" "+1-555-0006"
create_registration "$TMP_DIR/reg7_headers.txt" "$TMP_DIR/reg7_body.json" "$EVENT_ID_THREE" "Grace ${CASE_SUFFIX}" "grace-${CASE_SUFFIX}@example.com" "+1-555-0007"

# When
echo "STEP: When — fetch dashboard events list"
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
echo "STEP: Then — assert sorted events and registration counts"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -qi 'content-type: application/json' "$RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected JSON content type"; exit 1; }
grep -F "\"id\":\"${EVENT_ID_ONE}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected first event id in response"; exit 1; }
grep -F "\"id\":\"${EVENT_ID_TWO}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected second event id in response"; exit 1; }
grep -F "\"id\":\"${EVENT_ID_THREE}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected third event id in response"; exit 1; }
grep -F '"registrationCount":2' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount 2 in response"; exit 1; }
grep -F '"registrationCount":0' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount 0 in response"; exit 1; }
grep -F '"registrationCount":5' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount 5 in response"; exit 1; }
grep -F '"startDate"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected startDate field in response"; exit 1; }
grep -F '"endDate"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected endDate field in response"; exit 1; }
POS_TWO="$(grep -bo "\"id\":\"${EVENT_ID_TWO}\"" "$RESPONSE_BODY" | head -1 | cut -d: -f1)"
POS_ONE="$(grep -bo "\"id\":\"${EVENT_ID_ONE}\"" "$RESPONSE_BODY" | head -1 | cut -d: -f1)"
POS_THREE="$(grep -bo "\"id\":\"${EVENT_ID_THREE}\"" "$RESPONSE_BODY" | head -1 | cut -d: -f1)"
[ -n "$POS_TWO" ] || { echo "ASSERTION_FAILED: expected position for second event"; exit 1; }
[ -n "$POS_ONE" ] || { echo "ASSERTION_FAILED: expected position for first event"; exit 1; }
[ -n "$POS_THREE" ] || { echo "ASSERTION_FAILED: expected position for third event"; exit 1; }
[ "$POS_TWO" -lt "$POS_ONE" ] || { echo "ASSERTION_FAILED: expected workshop event to be first by startDate"; exit 1; }
[ "$POS_ONE" -lt "$POS_THREE" ] || { echo "ASSERTION_FAILED: expected annual meeting event to be last by startDate"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events and registrations"

echo "CODEVALID_TEST_ASSERTION_OK:retrieve_active_events_dashboard_success"
