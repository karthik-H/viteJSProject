#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TODAY="$(date -u +%F)"
EVENT_TITLE="Active Event ${CASE_SUFFIX}"
ATTENDEE_EMAIL="john.doe.${CASE_SUFFIX}@example.com"
TMP_DIR="$(mktemp -d)"
EVENT_RESPONSE="$TMP_DIR/event.json"
REG_RESPONSE="$TMP_DIR/registration.json"
STATUS_FILE="$TMP_DIR/status.txt"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
EVENT_HTTP_CODE="$(curl -sS -o "$EVENT_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Active registration event\",\"startDate\":\"${TODAY}\",\"endDate\":\"${TODAY}\",\"location\":\"Dashboard Hall\"}")"
[ "$EVENT_HTTP_CODE" = "201" ]
EVENT_ID="$(sed -n 's/.*\"id\":\"\([^\"]*\)\".*/\1/p' "$EVENT_RESPONSE" | head -n 1)"
[ -n "$EVENT_ID" ]

# When
curl -sS -o "$REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"John Doe\",\"email\":\"${ATTENDEE_EMAIL}\",\"phone\":\"+1-555-123-4567\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -Eq '"id":"reg_[^"]+"' "$REG_RESPONSE"
grep -F "\"eventId\":\"${EVENT_ID}\"" "$REG_RESPONSE" >/dev/null
grep -F '"name":"John Doe"' "$REG_RESPONSE" >/dev/null
grep -F "\"email\":\"${ATTENDEE_EMAIL}\"" "$REG_RESPONSE" >/dev/null
grep -F '"phone":"+1-555-123-4567"' "$REG_RESPONSE" >/dev/null
grep -Eq '"registeredAt":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[^"]+"' "$REG_RESPONSE"
echo "CODEVALID_TEST_ASSERTION_OK:happy_path_successful_registration"

# Cleanup
# No cleanup endpoint exists for this in-memory API; test data is isolated by unique suffix.
