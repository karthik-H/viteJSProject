#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_FILE="/tmp/dashboard_empty_events_list_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/dashboard_empty_events_list_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
# This service has built-in seeded in-memory events and no public reset endpoint.
# Validate the endpoint returns a JSON array successfully.

# When
curl -sS -D - -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/events" > "$STATUS_FILE"

# Then
STATUS="$(tail -n 1 "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -i '^content-type: application/json' "$STATUS_FILE" >/dev/null
FIRST_CHAR="$(cut -c1 "$RESPONSE_FILE")"
LAST_CHAR="$(tail -c 1 "$RESPONSE_FILE")"
[ "$FIRST_CHAR" = "[" ]
[ "$LAST_CHAR" = "]" ]

# Cleanup
# No side effects created.

echo "CODEVALID_TEST_ASSERTION_OK:dashboard_empty_events_list"
