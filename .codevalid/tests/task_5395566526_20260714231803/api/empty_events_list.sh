#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"
UNIQUE_TITLE="No Such Event ${CASE_SUFFIX}"

cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
 echo "STEP: Given — do not create any test-specific events before fetching the list"
echo "PREREQ: unique marker title is ${UNIQUE_TITLE}"

# When
 echo "STEP: When — fetch events list"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -X GET "$BASE_URL/api/events" \
  -H 'Accept: application/json')"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"

# Then
 echo "STEP: Then — assert HTTP 200 and either empty array or no seeded test-specific entries"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -qi 'content-type: application/json' "$RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected JSON content type"; exit 1; }
grep -q '^\[' "$RESPONSE_BODY" || { echo "ASSERTION_FAILED: expected response body to be a JSON array"; exit 1; }
if [ "$(tr -d '[:space:]' < "$RESPONSE_BODY")" = "[]" ]; then
  :
else
  ! grep -F "$UNIQUE_TITLE" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected no test-specific event in response"; exit 1; }
fi

# Cleanup
 echo "STEP: Cleanup — no side effects were created"

echo "CODEVALID_TEST_ASSERTION_OK:empty_events_list"
