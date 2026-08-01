#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
EARLY_HEADERS="$TMP_DIR/early_headers.txt"
EARLY_BODY="$TMP_DIR/early_body.json"
MID_HEADERS="$TMP_DIR/mid_headers.txt"
MID_BODY="$TMP_DIR/mid_body.json"
LATE_HEADERS="$TMP_DIR/late_headers.txt"
LATE_BODY="$TMP_DIR/late_body.json"
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
{"title":"${title}","description":"sorting test","startDate":"${start_date}","endDate":"${end_date}","location":"${location}"}
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

# Given
 echo "STEP: Given — create early, middle, and late events with distinct start dates"
create_event "$LATE_HEADERS" "$LATE_BODY" "Late Event ${CASE_SUFFIX}" "2099-12-01" "2099-12-05" "Late Hall ${CASE_SUFFIX}"
create_event "$EARLY_HEADERS" "$EARLY_BODY" "Early Event ${CASE_SUFFIX}" "2099-01-15" "2099-01-20" "Early Hall ${CASE_SUFFIX}"
create_event "$MID_HEADERS" "$MID_BODY" "Mid Event ${CASE_SUFFIX}" "2099-06-10" "2099-06-15" "Mid Hall ${CASE_SUFFIX}"

EARLY_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EARLY_BODY" | head -1)"
MID_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$MID_BODY" | head -1)"
LATE_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$LATE_BODY" | head -1)"
[ -n "$EARLY_ID" ] || { echo "ASSERTION_FAILED: expected early event id"; exit 1; }
[ -n "$MID_ID" ] || { echo "ASSERTION_FAILED: expected mid event id"; exit 1; }
[ -n "$LATE_ID" ] || { echo "ASSERTION_FAILED: expected late event id"; exit 1; }

# When
 echo "STEP: When — fetch events list for sort order verification"
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
 echo "STEP: Then — assert events are ordered by startDate ascending"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
POS_EARLY="$(grep -bo "\"id\":\"${EARLY_ID}\"" "$RESPONSE_BODY" | head -1 | cut -d: -f1)"
POS_MID="$(grep -bo "\"id\":\"${MID_ID}\"" "$RESPONSE_BODY" | head -1 | cut -d: -f1)"
POS_LATE="$(grep -bo "\"id\":\"${LATE_ID}\"" "$RESPONSE_BODY" | head -1 | cut -d: -f1)"
[ -n "$POS_EARLY" ] || { echo "ASSERTION_FAILED: expected early event in response"; exit 1; }
[ -n "$POS_MID" ] || { echo "ASSERTION_FAILED: expected mid event in response"; exit 1; }
[ -n "$POS_LATE" ] || { echo "ASSERTION_FAILED: expected late event in response"; exit 1; }
[ "$POS_EARLY" -lt "$POS_MID" ] || { echo "ASSERTION_FAILED: expected early event before mid event"; exit 1; }
[ "$POS_MID" -lt "$POS_LATE" ] || { echo "ASSERTION_FAILED: expected mid event before late event"; exit 1; }

# Cleanup
 echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events and registrations"

echo "CODEVALID_TEST_ASSERTION_OK:events_sorted_by_start_date"
