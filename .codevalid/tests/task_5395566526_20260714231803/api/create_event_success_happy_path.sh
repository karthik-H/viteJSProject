#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EVENT_TITLE="Tech Conference 2025 ${CASE_SUFFIX}"
CREATE_BODY_FILE="/tmp/create_event_success_happy_path_${CASE_SUFFIX}.json"
CREATE_STATUS_FILE="/tmp/create_event_success_happy_path_${CASE_SUFFIX}.status"
LIST_BODY_FILE="/tmp/create_event_success_happy_path_list_${CASE_SUFFIX}.json"
cleanup_files() {
  rm -f "$CREATE_BODY_FILE" "$CREATE_STATUS_FILE" "$LIST_BODY_FILE"
}
trap cleanup_files EXIT

# Given
: > "$CREATE_BODY_FILE"

# When
curl -sS -o "$CREATE_BODY_FILE" -w '%{http_code}' \
  -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Annual tech meetup\",\"startDate\":\"2025-06-01\",\"endDate\":\"2025-06-03\",\"location\":\"Convention Center\"}" \
  > "$CREATE_STATUS_FILE"

# Then
STATUS="$(cat "$CREATE_STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F '"title":"'"$EVENT_TITLE"'"' "$CREATE_BODY_FILE" >/dev/null
grep -F '"description":"Annual tech meetup"' "$CREATE_BODY_FILE" >/dev/null
grep -F '"startDate":"2025-06-01"' "$CREATE_BODY_FILE" >/dev/null
grep -F '"endDate":"2025-06-03"' "$CREATE_BODY_FILE" >/dev/null
grep -F '"location":"Convention Center"' "$CREATE_BODY_FILE" >/dev/null
grep -F '"registrationCount":0' "$CREATE_BODY_FILE" >/dev/null
EVENT_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$CREATE_BODY_FILE" | head -n 1)"
[ -n "$EVENT_ID" ]
curl -sS "$BASE_URL/api/events" > "$LIST_BODY_FILE"
grep -F '"id":"'"$EVENT_ID"'"' "$LIST_BODY_FILE" >/dev/null
grep -F '"title":"'"$EVENT_TITLE"'"' "$LIST_BODY_FILE" >/dev/null
printf 'CODEVALID_TEST_ASSERTION_OK:create_event_success_happy_path\n'

# Cleanup
# No cleanup endpoint exists for in-memory events; unique test data avoids collisions within isolated test runs.
