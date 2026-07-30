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

START_DATE="$((0))"
END_DATE="$((0))"
START_DATE="$(date -u +%F)"
END_DATE="$(date -u -d "$START_DATE + 5 day" +%F 2>/dev/null || date -u -v+5d +%F)"
EVENT_TITLE="Date Validation Test ${CASE_SUFFIX}"

create_registration() {
  out_headers="$1"
  out_body="$2"
  attendee_name="$3"
  attendee_email="$4"
  echo "PREREQ: registering attendee ${attendee_email}"
  cat > "$REQUEST_BODY_FILE" <<EOF
{"eventId":"${EVENT_ID}","name":"${attendee_name}","email":"${attendee_email}","phone":"+1-555-3300"}
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

# Given
echo "STEP: Given — create event with known dates and two registrations"
echo "PREREQ: creating validation test event"
cat > "$REQUEST_BODY_FILE" <<EOF
{"title":"${EVENT_TITLE}","description":"field verification event","startDate":"${START_DATE}","endDate":"${END_DATE}","location":"Validation Room"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
CREATE_CODE="$(curl -sS -D "$TMP_DIR/create_headers.txt" -o "$TMP_DIR/create_body.json" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data @"$REQUEST_BODY_FILE")"
echo "RESPONSE_STATUS: $CREATE_CODE"
echo "RESPONSE_HEADERS:"
cat "$TMP_DIR/create_headers.txt"
echo "RESPONSE_BODY:"
cat "$TMP_DIR/create_body.json"
[ "$CREATE_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${CREATE_CODE} while creating event"; exit 1; }
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$TMP_DIR/create_body.json" | head -1)"
[ -n "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected event id"; exit 1; }
create_registration "$TMP_DIR/reg1_headers.txt" "$TMP_DIR/reg1_body.json" "Validator One ${CASE_SUFFIX}" "validator-one-${CASE_SUFFIX}@example.com"
create_registration "$TMP_DIR/reg2_headers.txt" "$TMP_DIR/reg2_body.json" "Validator Two ${CASE_SUFFIX}" "validator-two-${CASE_SUFFIX}@example.com"

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
echo "STEP: Then — assert event includes required fields for UI date validation"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -F "\"id\":\"${EVENT_ID}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected event id in response"; exit 1; }
grep -F "${EVENT_TITLE}" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected event title in response"; exit 1; }
grep -F "\"startDate\":\"${START_DATE}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected startDate in response"; exit 1; }
grep -F "\"endDate\":\"${END_DATE}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected endDate in response"; exit 1; }
grep -F '"registrationCount":2' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount 2 in response"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events and registrations"

echo "CODEVALID_TEST_ASSERTION_OK:event_response_structure"
