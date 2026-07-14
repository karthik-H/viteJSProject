#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TODAY="$(date -u +%F)"
EMAIL_SHARED="shared.email.${CASE_SUFFIX}@example.com"
TMP_DIR="$(mktemp -d)"
EVENT_ONE_RESPONSE="$TMP_DIR/event-one.json"
EVENT_TWO_RESPONSE="$TMP_DIR/event-two.json"
FIRST_REG_RESPONSE="$TMP_DIR/first-registration.json"
SECOND_REG_RESPONSE="$TMP_DIR/second-registration.json"
STATUS_FILE="$TMP_DIR/status.txt"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
EVENT_ONE_STATUS="$(curl -sS -o "$EVENT_ONE_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"Shared Email Event A ${CASE_SUFFIX}\",\"description\":\"First event\",\"startDate\":\"${TODAY}\",\"endDate\":\"${TODAY}\",\"location\":\"Room A\"}")"
[ "$EVENT_ONE_STATUS" = "201" ]
EVENT_ONE_ID="$(sed -n 's/.*\"id\":\"\([^\"]*\)\".*/\1/p' "$EVENT_ONE_RESPONSE" | head -n 1)"
[ -n "$EVENT_ONE_ID" ]
EVENT_TWO_STATUS="$(curl -sS -o "$EVENT_TWO_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"Shared Email Event B ${CASE_SUFFIX}\",\"description\":\"Second event\",\"startDate\":\"${TODAY}\",\"endDate\":\"${TODAY}\",\"location\":\"Room B\"}")"
[ "$EVENT_TWO_STATUS" = "201" ]
EVENT_TWO_ID="$(sed -n 's/.*\"id\":\"\([^\"]*\)\".*/\1/p' "$EVENT_TWO_RESPONSE" | head -n 1)"
[ -n "$EVENT_TWO_ID" ]
FIRST_REG_STATUS="$(curl -sS -o "$FIRST_REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ONE_ID}\",\"name\":\"Shared Email Original\",\"email\":\"${EMAIL_SHARED}\",\"phone\":\"+1-555-555-0001\"}")"
[ "$FIRST_REG_STATUS" = "201" ]

# When
curl -sS -o "$SECOND_REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_TWO_ID}\",\"name\":\"Shared Email User\",\"email\":\"${EMAIL_SHARED}\",\"phone\":\"+1-555-555-6666\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "201" ]
grep -Eq '"id":"reg_[^"]+"' "$SECOND_REG_RESPONSE"
grep -F "\"eventId\":\"${EVENT_TWO_ID}\"" "$SECOND_REG_RESPONSE" >/dev/null
grep -F "\"email\":\"${EMAIL_SHARED}\"" "$SECOND_REG_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:duplicate_email_different_event"

# Cleanup
# No cleanup endpoint exists for this in-memory API; test data is isolated by unique suffix.
