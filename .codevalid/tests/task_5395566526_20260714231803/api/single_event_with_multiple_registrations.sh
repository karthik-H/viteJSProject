#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EVENT_TITLE="High Volume Event ${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/single_event_with_multiple_registrations_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/single_event_with_multiple_registrations_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
TODAY="$(date -u +%F)"
EVENT_RESPONSE="$(curl -sS -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"High volume registration count test\",\"startDate\":\"${TODAY}\",\"endDate\":\"${TODAY}\",\"location\":\"Main Arena\"}")"
EVENT_ID="$(printf '%s' "$EVENT_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')"
[ -n "$EVENT_ID" ]
I=1
while [ "$I" -le 5 ]; do
  EMAIL="bulk-${CASE_SUFFIX}-${I}@example.com"
  CODE="$(curl -sS -o /tmp/single_event_with_multiple_registrations_reg_${CASE_SUFFIX}_${I}.json -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
    -H 'Content-Type: application/json' \
    --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Bulk User ${I}\",\"email\":\"${EMAIL}\",\"phone\":\"+1-555-020-00${I}\"}")"
  [ "$CODE" = "201" ]
  rm -f "/tmp/single_event_with_multiple_registrations_reg_${CASE_SUFFIX}_${I}.json"
  I=$((I + 1))
done

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/events" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F "\"id\":\"${EVENT_ID}\"" "$RESPONSE_FILE" >/dev/null
grep -F '"registrationCount":5' "$RESPONSE_FILE" >/dev/null
REG_LIST_FILE="/tmp/single_event_with_multiple_registrations_list_${CASE_SUFFIX}.json"
LIST_CODE="$(curl -sS -o "$REG_LIST_FILE" -w '%{http_code}' "$BASE_URL/api/registrations/${EVENT_ID}")"
[ "$LIST_CODE" = "200" ]
grep -F 'bulk-' "$REG_LIST_FILE" >/dev/null
rm -f "$REG_LIST_FILE"

# Cleanup
# No API DELETE/reset endpoint exists for in-memory events or registrations created in Given.

echo "CODEVALID_TEST_ASSERTION_OK:single_event_with_multiple_registrations"
