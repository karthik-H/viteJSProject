#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EVENT_TITLE="Invalid Date Event ${CASE_SUFFIX}"
RESPONSE_FILE="/tmp/create_event_start_date_after_end_date_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/create_event_start_date_after_end_date_${CASE_SUFFIX}.status"
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
  --data "{\"title\":\"${EVENT_TITLE}\",\"startDate\":\"2025-08-10\",\"endDate\":\"2025-08-05\",\"location\":\"Hall A\"}" \
  > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "400" ]
grep -F 'Start date must be before or equal to the end date.' "$RESPONSE_FILE" >/dev/null
printf 'CODEVALID_TEST_ASSERTION_OK:create_event_start_date_after_end_date\n'

# Cleanup
# No Cleanup needed because the request is rejected before creating state.
