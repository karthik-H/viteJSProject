#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
TMP_DIR="$(mktemp -d)"
EVENT1_REQUEST_BODY="$TMP_DIR/event1_request.json"
EVENT1_RESPONSE_HEADERS="$TMP_DIR/event1_response_headers.txt"
EVENT1_RESPONSE_BODY="$TMP_DIR/event1_response_body.json"
EVENT2_REQUEST_BODY="$TMP_DIR/event2_request.json"
EVENT2_RESPONSE_HEADERS="$TMP_DIR/event2_response_headers.txt"
EVENT2_RESPONSE_BODY="$TMP_DIR/event2_response_body.json"
REG1_REQUEST_BODY="$TMP_DIR/reg1_request.json"
REG1_RESPONSE_HEADERS="$TMP_DIR/reg1_response_headers.txt"
REG1_RESPONSE_BODY="$TMP_DIR/reg1_response_body.json"
REG2_REQUEST_BODY="$TMP_DIR/reg2_request.json"
REG2_RESPONSE_HEADERS="$TMP_DIR/reg2_response_headers.txt"
REG2_RESPONSE_BODY="$TMP_DIR/reg2_response_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"
EVENT1_ID=""
EVENT2_ID=""

cleanup() {
  echo "STEP: Cleanup — remove temporary files"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Given
echo "STEP: Given — create two events and one registration on each"
echo "PREREQ: create target event"
cat > "$EVENT1_REQUEST_BODY" <<EOF
{"title":"Filter Target Event ${CASE_SUFFIX}","description":"Target event for filter verification","startDate":"2020-01-01","endDate":"2099-12-31","location":"Room A"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$EVENT1_REQUEST_BODY"
EVENT1_HTTP_CODE="$(curl -sS -D "$EVENT1_RESPONSE_HEADERS" -o "$EVENT1_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data @"$EVENT1_REQUEST_BODY")"
echo "RESPONSE_STATUS: $EVENT1_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$EVENT1_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$EVENT1_RESPONSE_BODY"
[ "$EVENT1_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${EVENT1_HTTP_CODE} while creating target event"; exit 1; }
EVENT1_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT1_RESPONSE_BODY" | head -n 1)"
[ -n "$EVENT1_ID" ] || { echo "ASSERTION_FAILED: expected non-empty target event id"; exit 1; }

echo "PREREQ: create other event"
cat > "$EVENT2_REQUEST_BODY" <<EOF
{"title":"Filter Other Event ${CASE_SUFFIX}","description":"Other event for exclusion verification","startDate":"2020-01-01","endDate":"2099-12-31","location":"Room B"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$EVENT2_REQUEST_BODY"
EVENT2_HTTP_CODE="$(curl -sS -D "$EVENT2_RESPONSE_HEADERS" -o "$EVENT2_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data @"$EVENT2_REQUEST_BODY")"
echo "RESPONSE_STATUS: $EVENT2_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$EVENT2_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$EVENT2_RESPONSE_BODY"
[ "$EVENT2_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${EVENT2_HTTP_CODE} while creating other event"; exit 1; }
EVENT2_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT2_RESPONSE_BODY" | head -n 1)"
[ -n "$EVENT2_ID" ] || { echo "ASSERTION_FAILED: expected non-empty other event id"; exit 1; }

echo "PREREQ: create Eve Davis registration on target event"
cat > "$REG1_REQUEST_BODY" <<EOF
{"eventId":"${EVENT1_ID}","name":"Eve Davis","email":"eve.${CASE_SUFFIX}@example.com","phone":"555-555-5555"}
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
[ "$REG1_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REG1_HTTP_CODE} while creating Eve registration"; exit 1; }
sleep 1

echo "PREREQ: create Frank Miller registration on other event"
cat > "$REG2_REQUEST_BODY" <<EOF
{"eventId":"${EVENT2_ID}","name":"Frank Miller","email":"frank.${CASE_SUFFIX}@example.com","phone":"666-666-6666"}
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
[ "$REG2_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REG2_HTTP_CODE} while creating Frank registration"; exit 1; }

# When
echo "STEP: When — retrieve registrations for the target event"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  "$BASE_URL/api/registrations/${EVENT1_ID}")"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$RESPONSE_BODY"

# Then
echo "STEP: Then — assert only target event registration is returned"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -F '"name":"Eve Davis"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected Eve Davis in response body"; exit 1; }
grep -F "\"eventId\":\"${EVENT1_ID}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected target eventId ${EVENT1_ID} in response body"; exit 1; }
if grep -F '"name":"Frank Miller"' "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: did not expect Frank Miller in response body"
  exit 1
fi
NAME_COUNT="$(grep -o '"name":' "$RESPONSE_BODY" | wc -l | tr -d ' ')"
[ "$NAME_COUNT" = "1" ] || { echo "ASSERTION_FAILED: expected exactly 1 registration got ${NAME_COUNT}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete API exists; unique test data isolates side effects"

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_filters_by_event_id"
