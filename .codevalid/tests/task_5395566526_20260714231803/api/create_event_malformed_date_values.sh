#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EVENT_TITLE="Bad Date Event ${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/create_event_malformed_date_values_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/create_event_malformed_date_values_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
# Current implementation only validates presence of date fields and whether startDate is greater than endDate.

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"startDate\":\"not-a-date\",\"endDate\":\"2025-11-01\",\"location\":\"Venue X\"}" \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F '"title":"'"$EVENT_TITLE"'"' "$RESPONSE_FILE" >/dev/null
grep -F '"startDate":"not-a-date"' "$RESPONSE_FILE" >/dev/null
grep -F '"endDate":"2025-11-01"' "$RESPONSE_FILE" >/dev/null
grep -F '"location":"Venue X"' "$RESPONSE_FILE" >/dev/null
grep -F '"registrationCount":0' "$RESPONSE_FILE" >/dev/null
printf 'CODEVALID_TEST_ASSERTION_OK:create_event_malformed_date_values\n'

# Cleanup
# No cleanup endpoint exists for in-memory events; this test documents current observable behavior.
