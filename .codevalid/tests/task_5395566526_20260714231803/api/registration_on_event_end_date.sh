#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TODAY="$(date -u +%F)"
ATTENDEE_EMAIL="end.date.${CASE_SUFFIX}@example.com"
TMP_DIR="$(mktemp -d)"
EVENT_RESPONSE="$TMP_DIR/event.json"
REG_RESPONSE="$TMP_DIR/registration.json"
STATUS_FILE="$TMP_DIR/status.txt"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
EVENT_STATUS="$(curl -sS -o "$EVENT_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"Boundary End Event ${CASE_SUFFIX}\",\"description\":\"End date boundary\",\"startDate\":\"${TODAY}\",\"endDate\":\"${TODAY}\",\"location\":\"Boundary Room\"}")"
[ "$EVENT_STATUS" = "201" ]
EVENT_ID="$(sed -n 's/.*\"id\":\"\([^\"]*\)\".*/\1/p' "$EVENT_RESPONSE" | head -n 1)"
[ -n "$EVENT_ID" ]

# When
curl -sS -o "$REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"End Date User\",\"email\":\"${ATTENDEE_EMAIL}\",\"phone\":\"+1-555-202-0602\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -F "\"eventId\":\"${EVENT_ID}\"" "$REG_RESPONSE" >/dev/null
grep -F '"name":"End Date User"' "$REG_RESPONSE" >/dev/null
grep -F "\"email\":\"${ATTENDEE_EMAIL}\"" "$REG_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:registration_on_event_end_date"

# Cleanup
# No cleanup endpoint exists for this in-memory API; test data is isolated by unique suffix.
