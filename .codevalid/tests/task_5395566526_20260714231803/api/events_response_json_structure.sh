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

  echo "PREREQ: creating event ${title}"
  cat > "$REQUEST_BODY_FILE" <<EOF
{"title":"${title}","description":"json structure verification","startDate":"${start_date}","endDate":"${end_date}","location":"JSON Hall"}
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

  echo "PREREQ: registering attendee ${attendee_email}"
  cat > "$REQUEST_BODY_FILE" <<EOF
{"eventId":"${event_id}","name":"${attendee_name}","email":"${attendee_email}","phone":"+1-555-4400"}
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
START_ONE="$TODAY"
END_ONE="$(date -u -d "$TODAY + 1 day" +%F 2>/dev/null || date -u -v+1d +%F)"
START_TWO="$(date -u -d "$TODAY + 4 day" +%F 2>/dev/null || date -u -v+4d +%F)"
END_TWO="$(date -u -d "$TODAY + 6 day" +%F 2>/dev/null || date -u -v+6d +%F)"

# Given
echo "STEP: Given — create two events each with one registration"
create_event "$TMP_DIR/event1_headers.txt" "$TMP_DIR/event1_body.json" "JSON Test Event 1 ${CASE_SUFFIX}" "$START_ONE" "$END_ONE"
create_event "$TMP_DIR/event2_headers.txt" "$TMP_DIR/event2_body.json" "JSON Test Event 2 ${CASE_SUFFIX}" "$START_TWO" "$END_TWO"
EVENT_ID_ONE="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$TMP_DIR/event1_body.json" | head -1)"
EVENT_ID_TWO="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$TMP_DIR/event2_body.json" | head -1)"
[ -n "$EVENT_ID_ONE" ] || { echo "ASSERTION_FAILED: expected first event id"; exit 1; }
[ -n "$EVENT_ID_TWO" ] || { echo "ASSERTION_FAILED: expected second event id"; exit 1; }
create_registration "$TMP_DIR/reg1_headers.txt" "$TMP_DIR/reg1_body.json" "$EVENT_ID_ONE" "JSON User One ${CASE_SUFFIX}" "json-one-${CASE_SUFFIX}@example.com"
create_registration "$TMP_DIR/reg2_headers.txt" "$TMP_DIR/reg2_body.json" "$EVENT_ID_TWO" "JSON User Two ${CASE_SUFFIX}" "json-two-${CASE_SUFFIX}@example.com"

# When
echo "STEP: When — fetch dashboard events list with JSON accept header"
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
echo "STEP: Then — assert response has expected JSON array structure"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -qi 'content-type: application/json' "$RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected JSON content type"; exit 1; }
grep -F '[' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected opening array bracket"; exit 1; }
grep -F ']' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected closing array bracket"; exit 1; }
grep -F '"id"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected id field in response"; exit 1; }
grep -F '"title"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected title field in response"; exit 1; }
grep -F '"startDate"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected startDate field in response"; exit 1; }
grep -F '"endDate"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected endDate field in response"; exit 1; }
grep -F '"registrationCount":1' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount 1 in response"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events and registrations"

echo "CODEVALID_TEST_ASSERTION_OK:events_response_json_structure"
