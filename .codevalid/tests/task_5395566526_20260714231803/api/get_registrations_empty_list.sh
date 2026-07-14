#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
EVENT_TITLE="Empty Registrations Event ${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
EVENT_RESPONSE="$TMP_DIR/event.json"
RESPONSE_FILE="$TMP_DIR/registrations.json"
STATUS_FILE="$TMP_DIR/status.txt"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given — create an event but do not create any registrations for it
CREATE_EVENT_CODE="$(curl -sS -o "$EVENT_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Event with no registrations\",\"startDate\":\"2020-01-01\",\"endDate\":\"2099-12-31\",\"location\":\"Room A\"}")"
[ "$CREATE_EVENT_CODE" = "201" ]
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$EVENT_RESPONSE" | head -n 1)"
[ -n "$EVENT_ID" ]

# When — request registrations for the event
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/registrations/${EVENT_ID}" > "$STATUS_FILE"

# Then — expect HTTP 200 with an empty array
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
BODY_COMPACT="$(tr -d '\n[:space:]' < "$RESPONSE_FILE")"
[ "$BODY_COMPACT" = "[]" ]

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_empty_list"

# Cleanup — no delete API exists for in-memory events/registrations; side effects are isolated with unique data
