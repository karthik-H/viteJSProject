#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EVENT_TITLE="One-Day Workshop ${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/create_event_start_and_end_same_date_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/create_event_start_and_end_same_date_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
:

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"startDate\":\"2025-09-01\",\"endDate\":\"2025-09-01\",\"location\":\"Room 101\"}" \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F '"title":"'"$EVENT_TITLE"'"' "$RESPONSE_FILE" >/dev/null
grep -F '"startDate":"2025-09-01"' "$RESPONSE_FILE" >/dev/null
grep -F '"endDate":"2025-09-01"' "$RESPONSE_FILE" >/dev/null
grep -F '"location":"Room 101"' "$RESPONSE_FILE" >/dev/null
grep -F '"registrationCount":0' "$RESPONSE_FILE" >/dev/null
printf 'CODEVALID_TEST_ASSERTION_OK:create_event_start_and_end_same_date\n'

# Cleanup
# No cleanup endpoint exists for in-memory events; unique test data avoids collisions within isolated test runs.
