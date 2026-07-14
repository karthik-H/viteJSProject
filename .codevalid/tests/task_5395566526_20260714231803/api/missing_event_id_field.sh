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
NO_EVENT_EMAIL="no.event.${CASE_SUFFIX}@example.com"

# When
curl -sS -o "$REG_RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"name\":\"No Event User\",\"email\":\"${NO_EVENT_EMAIL}\",\"phone\":\"+1-555-111-2222\"}" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "400" ]
grep -F 'Event, name, email, and phone number are required.' "$REG_RESPONSE" >/dev/null
echo "CODEVALID_TEST_ASSERTION_OK:missing_event_id_field"

# Cleanup
# No persistent side effects were created.
