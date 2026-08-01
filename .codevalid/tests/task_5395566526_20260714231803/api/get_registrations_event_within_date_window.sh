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
EVENT_TITLE="Active Window Event ${CASE_SUFFIX}"
ACTIVE_EMAIL="active.${CASE_SUFFIX}@test.com"

cleanup() {
  echo "STEP: Cleanup — remove temporary files"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Given
echo "STEP: Given — create an event whose registration window includes today and add one registration"
echo "PREREQ: create active event"
cat > "$EVENT_REQUEST_BODY" <<EOF
{"title":"${EVENT_TITLE}","description":"Active event for registration retrieval","startDate":"2020-01-01","endDate":"2099-12-31","location":"Active Center"}
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
[ "$EVENT_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${EVENT_HTTP_CODE} while creating active event"; exit 1; }
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_RESPONSE_BODY" | head -n 1)"
[ -n "$EVENT_ID" ] || { echo "ASSERTION_FAILED: expected response body to contain non-empty event id"; exit 1; }

echo "PREREQ: create registration for event inside active date window"
cat > "$REG_REQUEST_BODY" <<EOF
{"eventId":"${EVENT_ID}","name":"Active Attendee","email":"${ACTIVE_EMAIL}","phone":"444-444-4444"}
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
[ "$REG_HTTP_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${REG_HTTP_CODE} while creating active registration"; exit 1; }

# When
echo "STEP: When — retrieve registrations for the active event"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  "$BASE_URL/api/registrations/${EVENT_ID}")"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$RESPONSE_BODY"

# Then
echo "STEP: Then — assert HTTP 200 and returned registration for active event"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -F '"eventId":"'"$EVENT_ID"'"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected eventId in response body"; exit 1; }
grep -F '"email":"'"$ACTIVE_EMAIL"'"' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected active attendee email in response body"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete API exists; unique test data isolates side effects"

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_event_within_date_window"
