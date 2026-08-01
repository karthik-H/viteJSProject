#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
POPULAR_HEADERS="$TMP_DIR/popular_headers.txt"
POPULAR_BODY="$TMP_DIR/popular_body.json"
EMPTY_HEADERS="$TMP_DIR/empty_headers.txt"
EMPTY_BODY="$TMP_DIR/empty_body.json"
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
{"title":"${title}","description":"registration count test","startDate":"${start_date}","endDate":"${end_date}","location":"${location}"}
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
DAY_AFTER_TOMORROW="$(date -u -d "$TODAY + 2 day" +%F 2>/dev/null || date -u -v+2d +%F)"
THREE_DAYS_OUT="$(date -u -d "$TODAY + 3 day" +%F 2>/dev/null || date -u -v+3d +%F)"

# Given
 echo "STEP: Given — create one popular event, one empty event, and three registrations"
create_event "$POPULAR_HEADERS" "$POPULAR_BODY" "Popular Event ${CASE_SUFFIX}" "$TODAY" "$TOMORROW" "Popular Hall ${CASE_SUFFIX}"
create_event "$EMPTY_HEADERS" "$EMPTY_BODY" "Empty Event ${CASE_SUFFIX}" "$DAY_AFTER_TOMORROW" "$THREE_DAYS_OUT" "Quiet Hall ${CASE_SUFFIX}"

POPULAR_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$POPULAR_BODY" | head -1)"
EMPTY_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EMPTY_BODY" | head -1)"
[ -n "$POPULAR_ID" ] || { echo "ASSERTION_FAILED: expected popular event id"; exit 1; }
[ -n "$EMPTY_ID" ] || { echo "ASSERTION_FAILED: expected empty event id"; exit 1; }

create_registration "$TMP_DIR/reg1_headers.txt" "$TMP_DIR/reg1_body.json" "$POPULAR_ID" "One ${CASE_SUFFIX}" "one-${CASE_SUFFIX}@example.com" "+1-555-2001"
create_registration "$TMP_DIR/reg2_headers.txt" "$TMP_DIR/reg2_body.json" "$POPULAR_ID" "Two ${CASE_SUFFIX}" "two-${CASE_SUFFIX}@example.com" "+1-555-2002"
create_registration "$TMP_DIR/reg3_headers.txt" "$TMP_DIR/reg3_body.json" "$POPULAR_ID" "Three ${CASE_SUFFIX}" "three-${CASE_SUFFIX}@example.com" "+1-555-2003"

# When
 echo "STEP: When — fetch events list to inspect registrationCount values"
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
 echo "STEP: Then — assert registration counts are accurate for populated and empty events"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
POPULAR_FRAGMENT="$(grep -o "{[^}]*\"id\":\"${POPULAR_ID}\"[^}]*}" "$RESPONSE_BODY" | head -1 || true)"
EMPTY_FRAGMENT="$(grep -o "{[^}]*\"id\":\"${EMPTY_ID}\"[^}]*}" "$RESPONSE_BODY" | head -1 || true)"
[ -n "$POPULAR_FRAGMENT" ] || { echo "ASSERTION_FAILED: expected popular event fragment in response"; exit 1; }
[ -n "$EMPTY_FRAGMENT" ] || { echo "ASSERTION_FAILED: expected empty event fragment in response"; exit 1; }
echo "$POPULAR_FRAGMENT" | grep -F '"registrationCount":3' >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected popular event registrationCount 3"; exit 1; }
echo "$EMPTY_FRAGMENT" | grep -F '"registrationCount":0' >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected empty event registrationCount 0"; exit 1; }

# Cleanup
 echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events and registrations"

echo "CODEVALID_TEST_ASSERTION_OK:registration_count_accuracy"
