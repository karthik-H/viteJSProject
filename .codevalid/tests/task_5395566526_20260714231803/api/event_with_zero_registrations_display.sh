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
{"title":"${title}","description":"zero registration verification","startDate":"${start_date}","endDate":"${end_date}","location":"${location}"}
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
  attendee_email="$4"

  echo "PREREQ: registering attendee ${attendee_email} for ${event_id}"
  cat > "$REQUEST_BODY_FILE" <<EOF
{"eventId":"${event_id}","name":"Other User ${CASE_SUFFIX}","email":"${attendee_email}","phone":"+1-555-2200"}
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
ZERO_START="$TODAY"
ZERO_END="$(date -u -d "$TODAY + 1 day" +%F 2>/dev/null || date -u -v+1d +%F)"
OTHER_START="$TODAY"
OTHER_END="$TODAY"

# Given
echo "STEP: Given — create target event with no registrations and another event with registrations"
create_event "$TMP_DIR/zero_headers.txt" "$TMP_DIR/zero_body.json" "Newly Created Event ${CASE_SUFFIX}" "$ZERO_START" "$ZERO_END" "Zero Hall"
create_event "$TMP_DIR/other_headers.txt" "$TMP_DIR/other_body.json" "Busy Event ${CASE_SUFFIX}" "$OTHER_START" "$OTHER_END" "Other Hall"
ZERO_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$TMP_DIR/zero_body.json" | head -1)"
OTHER_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$TMP_DIR/other_body.json" | head -1)"
[ -n "$ZERO_ID" ] || { echo "ASSERTION_FAILED: expected target event id"; exit 1; }
[ -n "$OTHER_ID" ] || { echo "ASSERTION_FAILED: expected other event id"; exit 1; }
create_registration "$TMP_DIR/other_reg_headers.txt" "$TMP_DIR/other_reg_body.json" "$OTHER_ID" "other-${CASE_SUFFIX}@example.com"

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
echo "STEP: Then — assert event with no registrations shows registrationCount zero"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -F "\"id\":\"${ZERO_ID}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected target event in response"; exit 1; }
grep -F '"registrationCount":0' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount 0 in response"; exit 1; }
grep -F '"registrationCount"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount field in response"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events and registrations"

echo "CODEVALID_TEST_ASSERTION_OK:event_with_zero_registrations_display"
