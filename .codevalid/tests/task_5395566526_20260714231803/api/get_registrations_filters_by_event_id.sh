#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
TMP_DIR="$(mktemp -d)"
EVENT1_RESPONSE="$TMP_DIR/event1.json"
EVENT2_RESPONSE="$TMP_DIR/event2.json"
RESPONSE_FILE="$TMP_DIR/registrations.json"
STATUS_FILE="$TMP_DIR/status.txt"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — create two events and one registration in each
EVENT1_CODE="$(curl -sS -o "$EVENT1_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"Filter Target Event ${CASE_SUFFIX}\",\"description\":\"Target event\",\"startDate\":\"2020-01-01\",\"endDate\":\"2099-12-31\",\"location\":\"Hall 1\"}")"
[ "$EVENT1_CODE" = "201" ]
EVENT1_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT1_RESPONSE" | head -n 1)"
[ -n "$EVENT1_ID" ]

EVENT2_CODE="$(curl -sS -o "$EVENT2_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"Filter Other Event ${CASE_SUFFIX}\",\"description\":\"Other event\",\"startDate\":\"2020-01-01\",\"endDate\":\"2099-12-31\",\"location\":\"Hall 2\"}")"
[ "$EVENT2_CODE" = "201" ]
EVENT2_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT2_RESPONSE" | head -n 1)"
[ -n "$EVENT2_ID" ]

curl -sS -o "$TMP_DIR/reg1.json" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT1_ID}\",\"name\":\"Eve Davis\",\"email\":\"eve.${CASE_SUFFIX}@example.com\",\"phone\":\"555-111-1111\"}" > "$TMP_DIR/reg1.status"
[ "$(cat "$TMP_DIR/reg1.status")" = "201" ]

curl -sS -o "$TMP_DIR/reg2.json" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT2_ID}\",\"name\":\"Frank Miller\",\"email\":\"frank.${CASE_SUFFIX}@example.com\",\"phone\":\"555-222-2222\"}" > "$TMP_DIR/reg2.status"
[ "$(cat "$TMP_DIR/reg2.status")" = "201" ]

# When — request registrations only for the first event
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/registrations/${EVENT1_ID}" > "$STATUS_FILE"

# Then — expect only Eve Davis for the requested event and exclude Frank Miller
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"name":"Eve Davis"' "$RESPONSE_FILE" >/dev/null
grep -F "\"eventId\":\"${EVENT1_ID}\"" "$RESPONSE_FILE" >/dev/null
if grep -F '"name":"Frank Miller"' "$RESPONSE_FILE" >/dev/null; then
  echo "unexpected registration for other event returned"
  exit 1
fi
NAME_COUNT="$(grep -o '"name":' "$RESPONSE_FILE" | wc -l | tr -d ' ')"
[ "$NAME_COUNT" = "1" ]

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_filters_by_event_id"

# Cleanup — no delete API exists for in-memory events/registrations; side effects are isolated with unique data
