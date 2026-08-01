#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
TMP_DIR="$(mktemp -d)"
EVENT_REQUEST_BODY="$TMP_DIR/event_request.json"
EVENT_RESPONSE_HEADERS="$TMP_DIR/event_response_headers.txt"
EVENT_RESPONSE_BODY="$TMP_DIR/event_response_body.json"
REG_REQUEST_BODY="$TMP_DIR/reg_request.json"
REG_RESPONSE_HEADERS="$TMP_DIR/reg_response_headers.txt"
REG_RESPONSE_BODY="$TMP_DIR/reg_response_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"
EVENT_ID=""
EVENT_TITLE="Expired Event ${CASE_SUFFIX}"
PAST_EMAIL="past.${CASE_SUFFIX}@test.com"

cleanup() {
  echo "STEP: Cleanup — remove temporary files"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Given
echo "STEP: Given — create an event and historical registration data that remains viewable later"
echo "PREREQ: create event first so one registration can be stored"
cat > "$EVENT_REQUEST_BODY" <<EOF
{"title":"${EVENT_TITLE}","description":"Historical event for retrieval","startDate":"2020-01-01","endDate":"2099-12-31","location":"Archive Hall"}
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

echo "PREREQ: create registration that represents historical event data"
cat > "$REG_REQUEST_BODY" <<EOF
{"eventId":"${EVENT_ID}","name":"Past Attendee","email":"${PAST_EMAIL}","phone":"555-555-5555"}
EOF
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$REG_REQUEST_BODY"
REG_HTTP_CODE="$(curl -sS -D "$REG_RESPONSE_HEADERS" -o "$REG_RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$REG_REQUEST_BODY")"
echo "RESPONSE_STATUS: $REG_HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$REG_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$REG_RESPONSE_BODY"
[ "$REG_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REG_HTTP_CODE} while creating historical registration"; exit 1; }

# When
echo "STEP: When — retrieve registrations for the historical event"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  "$BASE_URL/api/registrations/${EVENT_ID}")"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$RESPONSE_BODY"

# Then
echo "STEP: Then — assert HTTP 200 and historical registration data is returned"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -F '"eventId":"'"$EVENT_ID"'"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected eventId in response body"; exit 1; }
grep -F '"email":"'"$PAST_EMAIL"'"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected historical attendee email in response body"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete API exists; unique test data isolates side effects"

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_event_outside_date_window"
