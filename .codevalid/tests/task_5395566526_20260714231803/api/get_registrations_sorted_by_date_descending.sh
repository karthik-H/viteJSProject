#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
TMP_DIR="$(mktemp -d)"
EVENT_REQUEST_BODY="$TMP_DIR/event_request.json"
EVENT_RESPONSE_HEADERS="$TMP_DIR/event_response_headers.txt"
EVENT_RESPONSE_BODY="$TMP_DIR/event_response_body.json"
REG1_REQUEST_BODY="$TMP_DIR/reg1_request.json"
REG1_RESPONSE_HEADERS="$TMP_DIR/reg1_response_headers.txt"
REG1_RESPONSE_BODY="$TMP_DIR/reg1_response_body.json"
REG2_REQUEST_BODY="$TMP_DIR/reg2_request.json"
REG2_RESPONSE_HEADERS="$TMP_DIR/reg2_response_headers.txt"
REG2_RESPONSE_BODY="$TMP_DIR/reg2_response_body.json"
REG3_REQUEST_BODY="$TMP_DIR/reg3_request.json"
REG3_RESPONSE_HEADERS="$TMP_DIR/reg3_response_headers.txt"
REG3_RESPONSE_BODY="$TMP_DIR/reg3_response_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"
EVENT_ID=""
EVENT_TITLE="Sorted Registrations Event ${CASE_SUFFIX}"
EMAIL_A="older.${CASE_SUFFIX}@test.com"
EMAIL_B="middle.${CASE_SUFFIX}@test.com"
EMAIL_C="newer.${CASE_SUFFIX}@test.com"

cleanup() {
  echo "STEP: Cleanup — remove temporary files"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Given
echo "STEP: Given — create an event and three registrations in sequence"
echo "PREREQ: create event with active registration window"
cat > "$EVENT_REQUEST_BODY" <<EOF
{"title":"${EVENT_TITLE}","description":"Event for sort verification","startDate":"2020-01-01","endDate":"2099-12-31","location":"Sorting Room"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$EVENT_REQUEST_BODY"
EVENT_HTTP_CODE="$(curl -sS -D "$EVENT_RESPONSE_HEADERS" -o "$EVENT_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data @"$EVENT_REQUEST_BODY")"
echo "RESPONSE_STATUS: $EVENT_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$EVENT_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$EVENT_RESPONSE_BODY"
[ "$EVENT_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${EVENT_HTTP_CODE} while creating event"; exit 1; }
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_RESPONSE_BODY" | head -n 1)"
[ -n "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected response body to contain non-empty event id"; exit 1; }

echo "PREREQ: create oldest registration"
cat > "$REG1_REQUEST_BODY" <<EOF
{"eventId":"${EVENT_ID}","name":"User Older","email":"${EMAIL_A}","phone":"700-000-0001"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$REG1_REQUEST_BODY"
REG1_HTTP_CODE="$(curl -sS -D "$REG1_RESPONSE_HEADERS" -o "$REG1_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$REG1_REQUEST_BODY")"
echo "RESPONSE_STATUS: $REG1_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$REG1_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$REG1_RESPONSE_BODY"
[ "$REG1_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REG1_HTTP_CODE} while creating oldest registration"; exit 1; }
sleep 1

echo "PREREQ: create middle registration"
cat > "$REG2_REQUEST_BODY" <<EOF
{"eventId":"${EVENT_ID}","name":"User Middle","email":"${EMAIL_B}","phone":"700-000-0002"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$REG2_REQUEST_BODY"
REG2_HTTP_CODE="$(curl -sS -D "$REG2_RESPONSE_HEADERS" -o "$REG2_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$REG2_REQUEST_BODY")"
echo "RESPONSE_STATUS: $REG2_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$REG2_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$REG2_RESPONSE_BODY"
[ "$REG2_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REG2_HTTP_CODE} while creating middle registration"; exit 1; }
sleep 1

echo "PREREQ: create newest registration"
cat > "$REG3_REQUEST_BODY" <<EOF
{"eventId":"${EVENT_ID}","name":"User Newer","email":"${EMAIL_C}","phone":"700-000-0003"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$REG3_REQUEST_BODY"
REG3_HTTP_CODE="$(curl -sS -D "$REG3_RESPONSE_HEADERS" -o "$REG3_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$REG3_REQUEST_BODY")"
echo "RESPONSE_STATUS: $REG3_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$REG3_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$REG3_RESPONSE_BODY"
[ "$REG3_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REG3_HTTP_CODE} while creating newest registration"; exit 1; }

# When
echo "STEP: When — retrieve registrations for the event"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  "$BASE_URL/api/registrations/${EVENT_ID}")"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$RESPONSE_BODY"

# Then
echo "STEP: Then — assert HTTP 200 and descending order newest, middle, oldest"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -F '"email":"'"$EMAIL_A"'"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected oldest registration email in response body"; exit 1; }
grep -F '"email":"'"$EMAIL_B"'"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected middle registration email in response body"; exit 1; }
grep -F '"email":"'"$EMAIL_C"'"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected newest registration email in response body"; exit 1; }
EMAIL_COUNT="$(grep -o '"email":' "$RESPONSE_BODY" | wc -l | tr -d ' ')"
[ "$EMAIL_COUNT" = "3" ] || { echo "ASSERTION_FAILED: expected 3 registrations got ${EMAIL_COUNT}"; exit 1; }
POS_C="$(grep -bo '"email":"'"$EMAIL_C"'"' "$RESPONSE_BODY" | head -n 1 | cut -d: -f1)"
POS_B="$(grep -bo '"email":"'"$EMAIL_B"'"' "$RESPONSE_BODY" | head -n 1 | cut -d: -f1)"
POS_A="$(grep -bo '"email":"'"$EMAIL_A"'"' "$RESPONSE_BODY" | head -n 1 | cut -d: -f1)"
[ -n "$POS_C" ] || { echo "ASSERTION_FAILED: expected to find newest registration position in response"; exit 1; }
[ -n "$POS_B" ] || { echo "ASSERTION_FAILED: expected to find middle registration position in response"; exit 1; }
[ -n "$POS_A" ] || { echo "ASSERTION_FAILED: expected to find oldest registration position in response"; exit 1; }
[ "$POS_C" -lt "$POS_B" ] || { echo "ASSERTION_FAILED: expected newest registration before middle registration in response ordering"; exit 1; }
[ "$POS_B" -lt "$POS_A" ] || { echo "ASSERTION_FAILED: expected middle registration before oldest registration in response ordering"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete API exists; unique test data isolates side effects"

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_sorted_by_date_descending"
