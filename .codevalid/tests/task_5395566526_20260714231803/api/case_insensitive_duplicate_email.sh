#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TODAY="$(date -u +%F)"
LOWER_EMAIL="test.user.${CASE_SUFFIX}@example.com"
UPPER_EMAIL="TEST.USER.${CASE_SUFFIX}@EXAMPLE.COM"
TMP_DIR="$(mktemp -d)"
EVENT_RESPONSE="$TMP_DIR/event.json"
FIRST_REG_RESPONSE="$TMP_DIR/first-registration.json"
SECOND_REG_RESPONSE="$TMP_DIR/second-registration.json"
STATUS_FILE="$TMP_DIR/status.txt"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
EVENT_STATUS="$(curl -sS -o "$EVENT_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"Case Duplicate Event ${CASE_SUFFIX}\",\"description\":\"Case-insensitive duplicate test\",\"startDate\":\"${TODAY}\",\"endDate\":\"${TODAY}\",\"location\":\"Case Hall\"}")"
[ "$EVENT_STATUS" = "201" ]
EVENT_ID="$(sed -n 's/.*\"id\":\"\([^\"]*\)\".*/\1/p' "$EVENT_RESPONSE" | head -n 1)"
[ -n "$EVENT_ID" ]
FIRST_REG_STATUS="$(curl -sS -o "$FIRST_REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Original Case User\",\"email\":\"${LOWER_EMAIL}\",\"phone\":\"+1-555-777-0000\"}")"
[ "$FIRST_REG_STATUS" = "201" ]

# When
curl -sS -o "$SECOND_REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Case Different\",\"email\":\"${UPPER_EMAIL}\",\"phone\":\"+1-555-777-8888\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "400" ]
grep -F 'This email is already registered for this event.' "$SECOND_REG_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:case_insensitive_duplicate_email"

# Cleanup
# No cleanup endpoint exists for this in-memory API; test data is isolated by unique suffix.
