#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
REQUEST_BODY_FILE="$TMP_DIR/request_body.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"
NONEXISTENT_EVENT_ID="evt-nonexistent-${CASE_SUFFIX}"

cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — choose a guaranteed non-existent event id"
echo "PREREQ: using event id ${NONEXISTENT_EVENT_ID} that has not been created"

# When
echo "STEP: When — attempt registration for a non-existent event"
cat > "$REQUEST_BODY_FILE" <<EOF
{
  "eventId": "${NONEXISTENT_EVENT_ID}",
  "name": "Phantom User",
  "email": "phantom.${CASE_SUFFIX}@example.com",
  "phone": "+1-555-000-0000"
}
EOF

echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"; cat "$REQUEST_BODY_FILE"
HTTP_CODE="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/registrations" \
  -H 'Content-Type: application/json' \
  --data @"$REQUEST_BODY_FILE")"
echo "RESPONSE_STATUS: $HTTP_CODE"
echo "RESPONSE_HEADERS:"; cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"; cat "$RESPONSE_BODY"

# Then
echo "STEP: Then — assert event not found response"
[ "$HTTP_CODE" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${HTTP_CODE}"; exit 1; }
EXPECTED_MESSAGE='Event not found.'
grep -F "$EXPECTED_MESSAGE" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected message '${EXPECTED_MESSAGE}'"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no cleanup required"

echo "CODEVALID_TEST_ASSERTION_OK:event_not_found"
