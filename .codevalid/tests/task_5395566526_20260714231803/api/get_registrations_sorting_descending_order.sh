#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
TMP_DIR="$(mktemp -d)"
EVENT_REQUEST_BODY="$TMP_DIR/event_request.json"
EVENT_RESPONSE_HEADERS="$TMP_DIR/event_response_headers.txt"
EVENT_RESPONSE_BODY="$TMP_DIR/event_response_body.json"
REGA_REQUEST_BODY="$TMP_DIR/rega_request.json"
REGA_RESPONSE_HEADERS="$TMP_DIR/rega_response_headers.txt"
REGA_RESPONSE_BODY="$TMP_DIR/rega_response_body.json"
REGB_REQUEST_BODY="$TMP_DIR/regb_request.json"
REGB_RESPONSE_HEADERS="$TMP_DIR/regb_response_headers.txt"
REGB_RESPONSE_BODY="$TMP_DIR/regb_response_body.json"
REGC_REQUEST_BODY="$TMP_DIR/regc_request.json"
REGC_RESPONSE_HEADERS="$TMP_DIR/regc_response_headers.txt"
REGC_RESPONSE_BODY="$TMP_DIR/regc_response_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"
EVENT_ID=""
EVENT_TITLE="Sorting Event ${CASE_SUFFIX}"

cleanup() {
  echo "STEP: Cleanup — remove temporary files"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Given
echo "STEP: Given — create an event and three sequential registrations"
echo "PREREQ: create event ${EVENT_TITLE}"
cat > "$EVENT_REQUEST_BODY" <<EOF
{"title":"${EVENT_TITLE}","description":"Event for sort verification","startDate":"2020-01-01","endDate":"2099-12-31","location":"Sort Hall"}
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

echo "PREREQ: create oldest registration User A"
cat > "$REGA_REQUEST_BODY" <<EOF
{"eventId":"${EVENT_ID}","name":"User A","email":"usera.${CASE_SUFFIX}@example.com","phone":"700-000-0001"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$REGA_REQUEST_BODY"
REGA_HTTP_CODE="$(curl -sS -D "$REGA_RESPONSE_HEADERS" -o "$REGA_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$REGA_REQUEST_BODY")"
echo "RESPONSE_STATUS: $REGA_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$REGA_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$REGA_RESPONSE_BODY"
[ "$REGA_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REGA_HTTP_CODE} while creating User A registration"; exit 1; }
sleep 1

echo "PREREQ: create middle registration User B"
cat > "$REGB_REQUEST_BODY" <<EOF
{"eventId":"${EVENT_ID}","name":"User B","email":"userb.${CASE_SUFFIX}@example.com","phone":"700-000-0002"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$REGB_REQUEST_BODY"
REGB_HTTP_CODE="$(curl -sS -D "$REGB_RESPONSE_HEADERS" -o "$REGB_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$REGB_REQUEST_BODY")"
echo "RESPONSE_STATUS: $REGB_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$REGB_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$REGB_RESPONSE_BODY"
[ "$REGB_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REGB_HTTP_CODE} while creating User B registration"; exit 1; }
sleep 1

echo "PREREQ: create newest registration User C"
cat > "$REGC_REQUEST_BODY" <<EOF
{"eventId":"${EVENT_ID}","name":"User C","email":"userc.${CASE_SUFFIX}@example.com","phone":"700-000-0003"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$REGC_REQUEST_BODY"
REGC_HTTP_CODE="$(curl -sS -D "$REGC_RESPONSE_HEADERS" -o "$REGC_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$REGC_REQUEST_BODY")"
echo "RESPONSE_STATUS: $REGC_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$REGC_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$REGC_RESPONSE_BODY"
[ "$REGC_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REGC_HTTP_CODE} while creating User C registration"; exit 1; }

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
echo "STEP: Then — assert HTTP 200 and descending order User C, User B, User A"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -F '"name":"User A"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected User A in response body"; exit 1; }
grep -F '"name":"User B"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected User B in response body"; exit 1; }
grep -F '"name":"User C"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected User C in response body"; exit 1; }
NAME_COUNT="$(grep -o '"name":' "$RESPONSE_BODY" | wc -l | tr -d ' ')"
[ "$NAME_COUNT" = "3" ] || { echo "ASSERTION_FAILED: expected 3 registrations got ${NAME_COUNT}"; exit 1; }
USER_C_POS="$(grep -bo '"name":"User C"' "$RESPONSE_BODY" | head -n 1 | cut -d: -f1)"
USER_B_POS="$(grep -bo '"name":"User B"' "$RESPONSE_BODY" | head -n 1 | cut -d: -f1)"
USER_A_POS="$(grep -bo '"name":"User A"' "$RESPONSE_BODY" | head -n 1 | cut -d: -f1)"
[ -n "$USER_C_POS" ] || { echo "ASSERTION_FAILED: expected to find User C position in response"; exit 1; }
[ -n "$USER_B_POS" ] || { echo "ASSERTION_FAILED: expected to find User B position in response"; exit 1; }
[ -n "$USER_A_POS" ] || { echo "ASSERTION_FAILED: expected to find User A position in response"; exit 1; }
[ "$USER_C_POS" -lt "$USER_B_POS" ] || { echo "ASSERTION_FAILED: expected User C before User B in response ordering"; exit 1; }
[ "$USER_B_POS" -lt "$USER_A_POS" ] || { echo "ASSERTION_FAILED: expected User B before User A in response ordering"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete API exists; unique test data isolates side effects"

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_sorting_descending_order"
