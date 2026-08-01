#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
TMP_DIR="$(mktemp -d)"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"
MISSING_EVENT_ID="evt-nonexistent-${CASE_SUFFIX}"

cleanup() {
  echo "STEP: Cleanup — remove temporary files"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Given
echo "STEP: Given — choose an event id that does not exist"
echo "PREREQ: use unique missing event id ${MISSING_EVENT_ID} without creating a matching event"

# When
echo "STEP: When — request registrations for a non-existent event"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  "$BASE_URL/api/registrations/${MISSING_EVENT_ID}")"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$RESPONSE_BODY"

# Then
echo "STEP: Then — assert HTTP 404 with event not found message"
[ "$HTTP_CODE" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${HTTP_CODE}"; exit 1; }
grep -F '"message":"Event not found."' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected Event not found message in response body"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no side effects were created"

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_event_not_found"
