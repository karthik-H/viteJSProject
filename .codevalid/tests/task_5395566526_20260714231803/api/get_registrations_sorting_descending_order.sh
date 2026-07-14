#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
EVENT_TITLE="Sorting Event ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
EVENT_RESPONSE="$TMP_DIR/event.json"
RESPONSE_FILE="$TMP_DIR/registrations.json"
STATUS_FILE="$TMP_DIR/status.txt"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — create one event and three registrations in sequence so registeredAt values differ
CREATE_EVENT_CODE="$(curl -sS -o "$EVENT_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Event for descending sort validation\",\"startDate\":\"2020-01-01\",\"endDate\":\"2099-12-31\",\"location\":\"Sort Hall\"}")"
[ "$CREATE_EVENT_CODE" = "201" ]
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_RESPONSE" | head -n 1)"
[ -n "$EVENT_ID" ]

curl -sS -o "$TMP_DIR/reg_a.json" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"User A\",\"email\":\"usera.${CASE_SUFFIX}@example.com\",\"phone\":\"666-111-1111\"}" > "$TMP_DIR/reg_a.status"
[ "$(cat "$TMP_DIR/reg_a.status")" = "201" ]
sleep 1
curl -sS -o "$TMP_DIR/reg_b.json" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"User B\",\"email\":\"userb.${CASE_SUFFIX}@example.com\",\"phone\":\"666-222-2222\"}" > "$TMP_DIR/reg_b.status"
[ "$(cat "$TMP_DIR/reg_b.status")" = "201" ]
sleep 1
curl -sS -o "$TMP_DIR/reg_c.json" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"User C\",\"email\":\"userc.${CASE_SUFFIX}@example.com\",\"phone\":\"666-333-3333\"}" > "$TMP_DIR/reg_c.status"
[ "$(cat "$TMP_DIR/reg_c.status")" = "201" ]

# When — request registrations for the event
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/registrations/${EVENT_ID}" > "$STATUS_FILE"

# Then — expect registrations in descending order by registeredAt: User C, User B, User A
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F '"name":"User C"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"User B"' "$RESPONSE_FILE" >/dev/null
grep -F '"name":"User A"' "$RESPONSE_FILE" >/dev/null
NAME_COUNT="$(grep -o '"name":' "$RESPONSE_FILE" | wc -l | tr -d ' ')"
[ "$NAME_COUNT" = "3" ]
USER_C_POS="$(grep -bo '"name":"User C"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
USER_B_POS="$(grep -bo '"name":"User B"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
USER_A_POS="$(grep -bo '"name":"User A"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
[ "$USER_C_POS" -lt "$USER_B_POS" ]
[ "$USER_B_POS" -lt "$USER_A_POS" ]

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_sorting_descending_order"

# Cleanup — no delete API exists for in-memory events/registrations; side effects are isolated with unique data
