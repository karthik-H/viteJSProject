#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
EVENT_TITLE="Registrations Success Event ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
EVENT_RESPONSE="$TMP_DIR/event.json"
RESPONSE_FILE="$TMP_DIR/registrations.json"
STATUS_FILE="$TMP_DIR/status.txt"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — create an event and three registrations with distinct timestamps produced sequentially
CREATE_EVENT_CODE="$(curl -sS -o "$EVENT_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Event for registration retrieval success\",\"startDate\":\"2020-01-01\",\"endDate\":\"2099-12-31\",\"location\":\"Main Hall\"}")"
[ "$CREATE_EVENT_CODE" = "201" ]
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_RESPONSE" | head -n 1)"
[ -n "$EVENT_ID" ]

curl -sS -o "$TMP_DIR/reg1.json" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Alice Johnson\",\"email\":\"alice.${CASE_SUFFIX}@example.com\",\"phone\":\"111-111-1111\"}" > "$TMP_DIR/reg1.status"
[ "$(cat "$TMP_DIR/reg1.status")" = "201" ]
sleep 1
curl -sS -o "$TMP_DIR/reg2.json" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Bob Smith\",\"email\":\"bob.${CASE_SUFFIX}@example.com\",\"phone\":\"222-222-2222\"}" > "$TMP_DIR/reg2.status"
[ "$(cat "$TMP_DIR/reg2.status")" = "201" ]
sleep 1
curl -sS -o "$TMP_DIR/reg3.json" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Carol White\",\"email\":\"carol.${CASE_SUFFIX}@example.com\",\"phone\":\"333-333-3333\"}" > "$TMP_DIR/reg3.status"
[ "$(cat "$TMP_DIR/reg3.status")" = "201" ]

# When — request registrations for the created event
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/registrations/${EVENT_ID}" > "$STATUS_FILE"

# Then — expect HTTP 200, three registrations, sorted newest first
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"name":"Carol White"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Bob Smith"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"Alice Johnson"' "$RESPONSE_FILE" >/dev/null
NAME_COUNT="$(grep -o '"name":' "$RESPONSE_FILE" | wc -l | tr -d ' ')"
[ "$NAME_COUNT" = "3" ]
CAROL_POS="$(grep -bo '"name":"Carol White"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
BOB_POS="$(grep -bo '"name":"Bob Smith"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
ALICE_POS="$(grep -bo '"name":"Alice Johnson"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
[ "$CAROL_POS" -lt "$BOB_POS" ]
[ "$BOB_POS" -lt "$ALICE_POS" ]

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_for_existing_event_success"

# Cleanup — no delete API exists for in-memory events/registrations; side effects are isolated with unique data
