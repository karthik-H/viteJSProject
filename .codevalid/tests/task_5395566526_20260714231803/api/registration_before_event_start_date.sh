#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TODAY="$(date -u +%F)"
if TOMORROW="$(date -u -d "$TODAY + 1 day" +%F 2>/dev/null)"; then :; else TOMORROW="$(date -u -v+1d +%F)"; fi
EVENT_TITLE="Future Event ${CASE_SUFFIX}"
ATTENDEE_EMAIL="early.bird.${CASE_SUFFIX}@example.com"
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
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Future registration window\",\"startDate\":\"${TOMORROW}\",\"endDate\":\"${TOMORROW}\",\"location\":\"Future Venue\"}")"
[ "$EVENT_HTTP_CODE" = "201" ]
EVENT_ID="$(sed -n 's/.*\"id\":\"\([^\"]*\)\".*/\1/p' "$EVENT_RESPONSE" | head -n 1)"
[ -n "$EVENT_ID" ]

# When
curl -sS -o "$REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Early Bird\",\"email\":\"${ATTENDEE_EMAIL}\",\"phone\":\"+1-555-999-0000\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "400" ]
grep -F "Registration has not opened yet. Registration opens on ${TOMORROW}." "$REG_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:registration_before_event_start_date"

# Cleanup
# No cleanup endpoint exists for this in-memory API; test data is isolated by unique suffix.
