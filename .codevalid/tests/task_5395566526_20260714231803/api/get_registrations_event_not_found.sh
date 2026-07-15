#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="${CASE_SUFFIX:-$(date +%s)-$$}"
EVENT_ID="evt-nonexistent-${CASE_SUFFIX}"
TMP_DIR="$(mktemp -d)"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"

cleanup() {
  echo "STEP: Cleanup — remove temporary files"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Given
echo "STEP: Given — prepare a non-existent event id"
echo "PREREQ: using event id ${EVENT_ID} without creating any event"

# When
echo "STEP: When — request registrations for a non-existent event"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  "$BASE_URL/api/registrations/${EVENT_ID}")"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: <empty>"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$RESPONSE_BODY"

# Then
echo "STEP: Then — assert HTTP 404 with not found message"
[ "$HTTP_CODE" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${HTTP_CODE}"; exit 1; }
grep -F '"message":"Event not found."' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected Event not found message in response body"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no state created"

echo "CODEVALID_TEST_ASSERTION_OK:get_registrations_event_not_found"
