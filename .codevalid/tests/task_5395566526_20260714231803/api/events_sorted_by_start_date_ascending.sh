#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_FILE="/tmp/events_sorted_by_start_date_ascending_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/events_sorted_by_start_date_ascending_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
# Use the built-in seeded events from the in-memory store.

# When
curl -sS -D - -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/events" > "$STATUS_FILE"

# Then
STATUS="$(tail -n 1 "$STATUS_FILE")"
[ "$STATUS" = "200" ]
EVENT3_LINE="$(grep -bo '"id":"event_3"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
EVENT1_LINE="$(grep -bo '"id":"event_1"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
EVENT2_LINE="$(grep -bo '"id":"event_2"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
[ -n "$EVENT3_LINE" ]
[ -n "$EVENT1_LINE" ]
[ -n "$EVENT2_LINE" ]
[ "$EVENT3_LINE" -lt "$EVENT1_LINE" ]
[ "$EVENT1_LINE" -lt "$EVENT2_LINE" ]
grep -F '"startDate":' "$RESPONSE_FILE" >/dev/null

# Cleanup
# No side effects created.

echo "CODEVALID_TEST_ASSERTION_OK:events_sorted_by_start_date_ascending"
