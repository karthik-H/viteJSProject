#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
EVENT_HEADERS="$TMP_DIR/event_headers.txt"
EVENT_BODY="$TMP_DIR/event_body.json"
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
{"title":"${title}","description":"structure test","startDate":"${start_date}","endDate":"${end_date}","location":"${location}"}
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
TOMORROW="$(date -u -d "$TODAY + 1 day" +%F 2>/dev/null || date -u -v+1d +%F)"
EVENT_TITLE="Test Event ${CASE_SUFFIX}"

# Given
 echo "STEP: Given — create a test event and one registration"
create_event "$EVENT_HEADERS" "$EVENT_BODY" "$EVENT_TITLE" "$TODAY" "$TOMORROW" "Test Hall ${CASE_SUFFIX}"
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_BODY" | head -1)"
[ -n "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected created event id"; exit 1; }
create_registration "$REG_HEADERS" "$REG_BODY" "$EVENT_ID" "Registered User ${CASE_SUFFIX}" "registered-${CASE_SUFFIX}@example.com" "+1-555-3001"

# When
 echo "STEP: When — fetch events list and locate the created event"
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
 echo "STEP: Then — assert event response contains id, title, startDate, endDate, and registrationCount"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
EVENT_FRAGMENT="$(grep -o "{[^}]*\"id\":\"${EVENT_ID}\"[^}]*}" "$RESPONSE_BODY" | head -1 || true)"
[ -n "$EVENT_FRAGMENT" ] || { echo "ASSERTION_FAILED: expected created event fragment in response"; exit 1; }
echo "$EVENT_FRAGMENT" | grep -F "\"id\":\"${EVENT_ID}\"" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected id field with created id"; exit 1; }
echo "$EVENT_FRAGMENT" | grep -F "\"title\":\"${EVENT_TITLE}\"" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected title field with created title"; exit 1; }
echo "$EVENT_FRAGMENT" | grep -F "\"startDate\":\"${TODAY}\"" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected startDate field with created value"; exit 1; }
echo "$EVENT_FRAGMENT" | grep -F "\"endDate\":\"${TOMORROW}\"" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected endDate field with created value"; exit 1; }
echo "$EVENT_FRAGMENT" | grep -F '"registrationCount":1' >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount field with value 1"; exit 1; }

# Cleanup
 echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events and registrations"

echo "CODEVALID_TEST_ASSERTION_OK:event_response_structure"
