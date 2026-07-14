#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
EVENT_TITLE="Dashboard Event ${CASE_SUFFIX}"
EMAIL_ONE="dashboard-one-${CASE_SUFFIX}@example.com"
EMAIL_TWO="dashboard-two-${CASE_SUFFIX}@example.com"
RESPONSE_FILE="/tmp/retrieve_active_events_dashboard_success_${CASE_SUFFIX}.json"
STATUS_FILE="/tmp/retrieve_active_events_dashboard_success_${CASE_SUFFIX}.status"
REG1_BODY="/tmp/retrieve_active_events_dashboard_success_reg1_${CASE_SUFFIX}.json"
REG1_STATUS="/tmp/retrieve_active_events_dashboard_success_reg1_${CASE_SUFFIX}.status"
REG2_BODY="/tmp/retrieve_active_events_dashboard_success_reg2_${CASE_SUFFIX}.json"
REG2_STATUS="/tmp/retrieve_active_events_dashboard_success_reg2_${CASE_SUFFIX}.status"
cleanup_files() {
  rm -f "$RESPONSE_FILE" "$STATUS_FILE" "$REG1_BODY" "$REG1_STATUS" "$REG2_BODY" "$REG2_STATUS"
}
trap cleanup_files EXIT

# Given
TODAY="$(date -u +%F)"
EVENT_RESPONSE="$(curl -sS -X POST "$BASE_URL/api/events" \
  -H 'Content-Type: application/json' \
  --data "{\"title\":\"${EVENT_TITLE}\",\"description\":\"Dashboard retrieval test event\",\"startDate\":\"${TODAY}\",\"endDate\":\"${TODAY}\",\"location\":\"Test Hall\"}")"
EVENT_ID="$(printf '%s' "$EVENT_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')"
[ -n "$EVENT_ID" ]
printf '%s' "$EVENT_RESPONSE" | grep -F '"registrationCount":0' >/dev/null

curl -sS -o "$REG1_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Dashboard User One\",\"email\":\"${EMAIL_ONE}\",\"phone\":\"+1-555-000-0001\"}" > "$REG1_STATUS"
[ "$(cat "$REG1_STATUS")" = "201" ]

curl -sS -o "$REG2_BODY" -w '%{http_code}' -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data "{\"eventId\":\"${EVENT_ID}\",\"name\":\"Dashboard User Two\",\"email\":\"${EMAIL_TWO}\",\"phone\":\"+1-555-000-0002\"}" > "$REG2_STATUS"
[ "$(cat "$REG2_STATUS")" = "201" ]

# When
curl -sS -D - -o "$RESPONSE_FILE" -w '%{http_code}' "$BASE_URL/api/events" > "$STATUS_FILE"

# Then
STATUS="$(tail -n 1 "$STATUS_FILE")"
[ "$STATUS" = "200" ]
grep -i '^content-type: application/json' "$STATUS_FILE" >/dev/null
grep -F '"id":"event_3"' "$RESPONSE_FILE" >/dev/null
grep -F '"id":"event_1"' "$RESPONSE_FILE" >/dev/null
grep -F '"id":"event_2"' "$RESPONSE_FILE" >/dev/null
grep -F "\"id\":\"${EVENT_ID}\"" "$RESPONSE_FILE" >/dev/null
grep -F '"registrationCount":2' "$RESPONSE_FILE" >/dev/null
EVENT3_LINE="$(grep -bo '"id":"event_3"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
EVENT1_LINE="$(grep -bo '"id":"event_1"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
EVENT2_LINE="$(grep -bo '"id":"event_2"' "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
NEW_EVENT_LINE="$(grep -bo "\"id\":\"${EVENT_ID}\"" "$RESPONSE_FILE" | head -n 1 | cut -d: -f1)"
[ "$EVENT3_LINE" -lt "$EVENT1_LINE" ]
[ "$EVENT1_LINE" -lt "$EVENT2_LINE" ]
[ "$EVENT2_LINE" -lt "$NEW_EVENT_LINE" ]
REG_LIST_FILE="/tmp/retrieve_active_events_dashboard_success_list_${CASE_SUFFIX}.json"
REG_LIST_CODE="$(curl -sS -o "$REG_LIST_FILE" -w '%{http_code}' "$BASE_URL/api/registrations/${EVENT_ID}")"
[ "$REG_LIST_CODE" = "200" ]
grep -F "${EMAIL_ONE}" "$REG_LIST_FILE" >/dev/null
grep -F "${EMAIL_TWO}" "$REG_LIST_FILE" >/dev/null
rm -f "$REG_LIST_FILE"

# Cleanup
# No API DELETE/reset endpoint exists for in-memory events or registrations created in Given.

echo "CODEVALID_TEST_ASSERTION_OK:retrieve_active_events_dashboard_success"
