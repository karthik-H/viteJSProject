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

TODAY="$(date -u +%F)"
START_DATE="$(date -u -d "$TODAY - 1 day" +%F 2>/dev/null || date -u -v-1d +%F)"
END_DATE="$(date -u -d "$TODAY + 1 day" +%F 2>/dev/null || date -u -v+1d +%F)"

# Given
echo "STEP: Given — create a single event and many registrations"
echo "PREREQ: creating sold out event"
cat > "$REQUEST_BODY_FILE" <<EOF
{"title":"Sold Out Conference ${CASE_SUFFIX}","description":"multiple registrations test","startDate":"${START_DATE}","endDate":"${END_DATE}","location":"Grand Hall"}
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
[ -n "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected sold out event id"; exit 1; }

i=1
while [ "$i" -le 150 ]; do
  echo "PREREQ: registering attendee ${i} of 150"
  cat > "$REQUEST_BODY_FILE" <<EOF
{"eventId":"${EVENT_ID}","name":"Registrant ${i} ${CASE_SUFFIX}","email":"registrant-${i}-${CASE_SUFFIX}@example.com","phone":"+1-555-${i}"}
EOF
  echo "REQUEST_HEADERS: Content-Type: application/json"
  echo "REQUEST_BODY:"
  cat "$REQUEST_BODY_FILE"
  REG_CODE="$(curl -sS -D "$TMP_DIR/reg_${i}_headers.txt" -o "$TMP_DIR/reg_${i}_body.json" -w '%{http_code}' \
    -X POST "$BASE_URL/api/registrations" \
    -H 'Content-Type: application/json' \
    --data @"$REQUEST_BODY_FILE")"
  echo "RESPONSE_STATUS: $REG_CODE"
  echo "RESPONSE_HEADERS:"
  cat "$TMP_DIR/reg_${i}_headers.txt"
  echo "RESPONSE_BODY:"
  cat "$TMP_DIR/reg_${i}_body.json"
  [ "$REG_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REG_CODE} while creating registration ${i}"; exit 1; }
  i=$((i + 1))
done

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
echo "STEP: Then — assert single event reflects 150 registrations"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -F "\"id\":\"${EVENT_ID}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected sold out event id in response"; exit 1; }
grep -F '"registrationCount":150' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount 150 in response"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events and registrations"

echo "CODEVALID_TEST_ASSERTION_OK:single_event_with_multiple_registrations"
