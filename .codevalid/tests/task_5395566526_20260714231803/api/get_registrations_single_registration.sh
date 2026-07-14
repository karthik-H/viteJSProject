#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
EVENT_TITLE="Single Registration Event ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
EVENT_RESPONSE="$TMP_DIR/event.json"
RESPONSE_FILE="$TMP_DIR/registrations.json"
STATUS_FILE="$TMP_DIR/status.txt"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — create an event and exactly one registration
CREATE_EVENT_CODE="$(curl -sS -o "$EVENT_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Event with one attendee\",\"startDate\":\"2020-01-01\",\"endDate\":\"2099-12-31\",\"location\":\"Room B\"}")"
[ "$CREATE_EVENT_CODE" = "201" ]
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_RESPONSE" | head -n 1)"
[ -n "$EVENT_ID" ]

curl -sS -o "$TMP_DIR/reg.json" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"David Brown\",\"email\":\"david.${CASE_SUFFIX}@example.com\",\"phone\":\"444-444-4444\"}" > "$TMP_DIR/reg.status"
[ "$(cat "$TMP_DIR/reg.status")" = "201" ]

# When — request registrations for the event
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/registrations/${EVENT_ID}" > "$STATUS_FILE"

# Then — expect HTTP 200 with exactly one registration for David Brown
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"name":"David Brown"' "$RESPONSE_FILE" >/dev/null
grep -F "\"eventId\":\"${EVENT_ID}\"" "$RESPONSE_FILE" >/dev/null
NAME_COUNT="$(grep -o '"name":' "$RESPONSE_FILE" | wc -l | tr -d ' ')"
[ "$NAME_COUNT" = "1" ]

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_single_registration"

# Cleanup — no delete API exists for in-memory events/registrations; side effects are isolated with unique data
