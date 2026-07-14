#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TODAY="$(date -u +%F)"
EVENT_TITLE="Duplicate Email Event ${CASE_SUFFIX}"
DUPLICATE_EMAIL="already.registered.${CASE_SUFFIX}@example.com"
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
EVENT_HTTP_CODE="$(curl -sS -o "$EVENT_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Duplicate email event\",\"startDate\":\"${TODAY}\",\"endDate\":\"${TODAY}\",\"location\":\"Main Hall\"}")"
[ "$EVENT_HTTP_CODE" = "201" ]
EVENT_ID="$(sed -n 's/.*\"id\":\"\([^\"]*\)\".*/\1/p' "$EVENT_RESPONSE" | head -n 1)"
[ -n "$EVENT_ID" ]
FIRST_STATUS="$(curl -sS -o "$FIRST_REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Existing User\",\"email\":\"${DUPLICATE_EMAIL}\",\"phone\":\"+1-555-333-0000\"}")"
[ "$FIRST_STATUS" = "201" ]

# When
curl -sS -o "$SECOND_REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Duplicate User\",\"email\":\"${DUPLICATE_EMAIL}\",\"phone\":\"+1-555-333-4444\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "400" ]
grep -F 'This email is already registered for this event.' "$SECOND_REG_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:duplicate_email_registration_same_event"

# Cleanup
# No cleanup endpoint exists for this in-memory API; test data is isolated by unique suffix.
