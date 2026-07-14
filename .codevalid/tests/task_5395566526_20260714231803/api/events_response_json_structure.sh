#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_FILE="/tmp/events_response_json_structure_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/events_response_json_structure_${CASE_SUFFIX}.headers_and_status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE"
}
trap cleanup_files EXIT

# Given
# Use the public GET /api/events endpoint as-is and validate response structure.

# When
curl -sS -D - -o "$RESPONSE_FILE" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/events" > "$STATUS_FILE"

# Then
STATUS="$(tail -n 1 "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -i '^content-type: application/json' "$STATUS_FILE" >/dev/null
FIRST_CHAR="$(cut -c1 "$RESPONSE_FILE")"
LAST_CHAR="$(tail -c 1 "$RESPONSE_FILE")"
[ "$FIRST_CHAR" = "[" ]
[ "$LAST_CHAR" = "]" ]
grep -F '"id":' "$RESPONSE_FILE" >/dev/null
grep -F '"title":' "$RESPONSE_FILE" >/dev/null
grep -F '"startDate":' "$RESPONSE_FILE" >/dev/null
grep -F '"endDate":' "$RESPONSE_FILE" >/dev/null
grep -F '"registrationCount":' "$RESPONSE_FILE" >/dev/null

# Cleanup
# No side effects created.

echo "CODEVALID_TEST_ASSERTION_OK:events_response_json_structure"
