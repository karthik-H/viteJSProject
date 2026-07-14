#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EVENT_TITLE="Registration Count Event ${CASE_SUFFIX}"
EMAIL_ONE="count-one-${CASE_SUFFIX}@example.com"
EMAIL_TWO="count-two-${CASE_SUFFIX}@example.com"
RESPONSE_FILE="/tmp/registration_count_accurate_calculation_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/registration_count_accurate_calculation_${CASE_SUFFIX}.status"
REG1_BODY="/tmp/registration_count_accurate_calculation_reg1_${CASE_SUFFIX}.json"
REG1_STATUS="/tmp/registration_count_accurate_calculation_reg1_${CASE_SUFFIX}.status"
REG2_BODY="/tmp/registration_count_accurate_calculation_reg2_${CASE_SUFFIX}.json"
REG2_STATUS="/tmp/registration_count_accurate_calculation_reg2_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$REG1_BODY" "$REG1_STATUS" "$REG2_BODY" "$REG2_STATUS"
}
trap cleanup_files EXIT

# Given
TODAY="$(date -u +%F)"
EVENT_RESPONSE="$(curl -sS -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Registration count accuracy event\",\"startDate\":\"${TODAY}\",\"endDate\":\"${TODAY}\",\"location\":\"Count Center\"}")"
EVENT_ID="$(printf '%s' "$EVENT_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')"
[ -n "$EVENT_ID" ]

curl -sS -o "$REG1_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Count User One\",\"email\":\"${EMAIL_ONE}\",\"phone\":\"+1-555-010-0001\"}" > "$REG1_STATUS"
[ "$(cat "$REG1_STATUS")" = "201" ]

curl -sS -o "$REG2_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Count User Two\",\"email\":\"${EMAIL_TWO}\",\"phone\":\"+1-555-010-0002\"}" > "$REG2_STATUS"
[ "$(cat "$REG2_STATUS")" = "201" ]

# When
curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/events" > "$STATUS_FILE"

# Then
STATUS="$(cat "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -F "\"id\":\"${EVENT_ID}\"" "$RESPONSE_FILE" >/dev/null
grep -F '"registrationCount":2' "$RESPONSE_FILE" >/dev/null
REG_LIST_FILE="/tmp/registration_count_accurate_calculation_list_${CASE_SUFFIX}.json"
REG_LIST_CODE="$(curl -sS -o "$REG_LIST_FILE" -w '%{http_code}' "$BASE_URL/api/registrations/${EVENT_ID}")"
[ "$REG_LIST_CODE" = "200" ]
grep -F "${EMAIL_ONE}" "$REG_LIST_FILE" >/dev/null
grep -F "${EMAIL_TWO}" "$REG_LIST_FILE" >/dev/null
rm -f "$REG_LIST_FILE"

# Cleanup
# No API DELETE/reset endpoint exists for in-memory events or registrations created in Given.

echo "CODEVALID_TEST_ASSERTION_OK:registration_count_accurate_calculation"
