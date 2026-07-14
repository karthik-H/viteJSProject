#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
REG_RESPONSE="$TMP_DIR/registration.json"
STATUS_FILE="$TMP_DIR/status.txt"
cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
MISSING_EVENT_ID="evt-nonexistent-${CASE_SUFFIX}"
ATTENDEE_EMAIL="phantom.${CASE_SUFFIX}@example.com"

# When
curl -sS -o "$REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${MISSING_EVENT_ID}\",\"name\":\"Phantom User\",\"email\":\"${ATTENDEE_EMAIL}\",\"phone\":\"+1-555-000-0000\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "404" ]
grep -F 'Event not found.' "$REG_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:event_not_found"

# Cleanup
# No persistent side effects were created.
