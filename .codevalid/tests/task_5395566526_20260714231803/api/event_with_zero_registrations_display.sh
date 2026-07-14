#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EVENT_TITLE="Zero Registration Event ${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/event_with_zero_registrations_display_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/event_with_zero_registrations_display_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
TODAY="$(date -u +%F)"
EVENT_RESPONSE="$(curl -sS -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Zero registration display test\",\"startDate\":\"${TODAY}\",\"endDate\":\"${TODAY}\",\"location\":\"Quiet Room\"}")"
EVENT_ID="$(printf '%s' "$EVENT_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')"
[ -n "$EVENT_ID" ]
printf '%s' "$EVENT_RESPONSE" | grep -F '"registrationCount":0' >/dev/null

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/events" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F "\"id\":\"${EVENT_ID}\"" "$RESPONSE_FILE" >/dev/null
grep -F '"registrationCount":0' "$RESPONSE_FILE" >/dev/null

# Cleanup
# No API DELETE/reset endpoint exists for in-memory events created in Given.

echo "CODEVALID_TEST_ASSERTION_OK:event_with_zero_registrations_display"
