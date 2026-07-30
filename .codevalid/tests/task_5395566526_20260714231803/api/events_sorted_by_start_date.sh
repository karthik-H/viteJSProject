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
{"title":"${title}","description":"sort verification event","startDate":"${start_date}","endDate":"${end_date}","location":"Sort Hall"}
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

TODAY="$(date -u +%F)"
EARLY_START="$(date -u -d "$TODAY - 5 day" +%F 2>/dev/null || date -u -v-5d +%F)"
EARLY_END="$(date -u -d "$TODAY - 4 day" +%F 2>/dev/null || date -u -v-4d +%F)"
MID_START="$TODAY"
MID_END="$(date -u -d "$TODAY + 1 day" +%F 2>/dev/null || date -u -v+1d +%F)"
LATE_START="$(date -u -d "$TODAY + 10 day" +%F 2>/dev/null || date -u -v+10d +%F)"
LATE_END="$(date -u -d "$TODAY + 11 day" +%F 2>/dev/null || date -u -v+11d +%F)"

# Given
echo "STEP: Given — create events in non-chronological insertion order"
create_event "$TMP_DIR/mid_headers.txt" "$TMP_DIR/mid_body.json" "Mid-Year Summit ${CASE_SUFFIX}" "$MID_START" "$MID_END"
create_event "$TMP_DIR/late_headers.txt" "$TMP_DIR/late_body.json" "Year-End Gala ${CASE_SUFFIX}" "$LATE_START" "$LATE_END"
create_event "$TMP_DIR/early_headers.txt" "$TMP_DIR/early_body.json" "Early Bird Workshop ${CASE_SUFFIX}" "$EARLY_START" "$EARLY_END"

MID_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$TMP_DIR/mid_body.json" | head -1)"
LATE_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$TMP_DIR/late_body.json" | head -1)"
EARLY_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$TMP_DIR/early_body.json" | head -1)"
[ -n "$MID_ID" ] || { echo "ASSERTION_FAILED: expected mid event id"; exit 1; }
[ -n "$LATE_ID" ] || { echo "ASSERTION_FAILED: expected late event id"; exit 1; }
[ -n "$EARLY_ID" ] || { echo "ASSERTION_FAILED: expected early event id"; exit 1; }

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
echo "STEP: Then — assert events are sorted ascending by startDate"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
POS_EARLY="$(grep -bo "\"id\":\"${EARLY_ID}\"" "$RESPONSE_BODY" | head -1 | cut -d: -f1)"
POS_MID="$(grep -bo "\"id\":\"${MID_ID}\"" "$RESPONSE_BODY" | head -1 | cut -d: -f1)"
POS_LATE="$(grep -bo "\"id\":\"${LATE_ID}\"" "$RESPONSE_BODY" | head -1 | cut -d: -f1)"
[ -n "$POS_EARLY" ] || { echo "ASSERTION_FAILED: expected early event in response"; exit 1; }
[ -n "$POS_MID" ] || { echo "ASSERTION_FAILED: expected mid event in response"; exit 1; }
[ -n "$POS_LATE" ] || { echo "ASSERTION_FAILED: expected late event in response"; exit 1; }
[ "$POS_EARLY" -lt "$POS_MID" ] || { echo "ASSERTION_FAILED: expected early event before mid event"; exit 1; }
[ "$POS_MID" -lt "$POS_LATE" ] || { echo "ASSERTION_FAILED: expected mid event before late event"; exit 1; }
grep -F "\"startDate\":\"${EARLY_START}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected early startDate in response"; exit 1; }
grep -F "\"startDate\":\"${MID_START}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected mid startDate in response"; exit 1; }
grep -F "\"startDate\":\"${LATE_START}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected late startDate in response"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events"

echo "CODEVALID_TEST_ASSERTION_OK:events_sorted_by_start_date"
