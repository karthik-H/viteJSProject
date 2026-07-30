#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TMP_DIR="$(mktemp -d)"
REQUEST_BODY_FILE="$TMP_DIR/request.json"
RESPONSE_HEADERS="$TMP_DIR/response_headers.txt"
RESPONSE_BODY="$TMP_DIR/response_body.json"

cleanup_files() {
  rm -rf "$TMP_DIR"
}
trap cleanup_files EXIT

create_event() {
  out_headers="$1"
  out_body="$2"
  title="$3"
  start_date="$4"
  end_date="$5"

  echo "PREREQ: creating event ${title}"
  cat > "$REQUEST_BODY_FILE" <<EOF
{"title":"${title}","description":"count verification event","startDate":"${start_date}","endDate":"${end_date}","location":"Count Hall"}
EOF
  echo "REQUEST_HEADERS: Content-Type: application/json"
  echo "REQUEST_BODY:"
  cat "$REQUEST_BODY_FILE"
  code="$(curl -sS -D "$out_headers" -o "$out_body" -w '%{http_code}' \
    -X POST "$BASE_URL/api/events" \
    -H 'Content-Type: application/json' \
    --data @"$REQUEST_BODY_FILE")"
  echo "RESPONSE_STATUS: $code"
  echo "RESPONSE_HEADERS:"
  cat "$out_headers"
  echo "RESPONSE_BODY:"
  cat "$out_body"
  [ "$code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${code} while creating event"; exit 1; }
}

create_registration() {
  out_headers="$1"
  out_body="$2"
  event_id="$3"
  attendee_name="$4"
  attendee_email="$5"

  echo "PREREQ: registering attendee ${attendee_email} for ${event_id}"
  cat > "$REQUEST_BODY_FILE" <<EOF
{"eventId":"${event_id}","name":"${attendee_name}","email":"${attendee_email}","phone":"+1-555-1111"}
EOF
  echo "REQUEST_HEADERS: Content-Type: application/json"
  echo "REQUEST_BODY:"
  cat "$REQUEST_BODY_FILE"
  code="$(curl -sS -D "$out_headers" -o "$out_body" -w '%{http_code}' \
    -X POST "$BASE_URL/api/registrations" \
    -H 'Content-Type: application/json' \
    --data @"$REQUEST_BODY_FILE")"
  echo "RESPONSE_STATUS: $code"
  echo "RESPONSE_HEADERS:"
  cat "$out_headers"
  echo "RESPONSE_BODY:"
  cat "$out_body"
  [ "$code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 201 got ${code} while creating registration"; exit 1; }
}

TODAY="$(date -u +%F)"
POPULAR_START="$(date -u -d "$TODAY - 1 day" +%F 2>/dev/null || date -u -v-1d +%F)"
POPULAR_END="$TODAY"
NICHE_START="$TODAY"
NICHE_END="$(date -u -d "$TODAY + 1 day" +%F 2>/dev/null || date -u -v+1d +%F)"

# Given
echo "STEP: Given — create events with different registration totals"
create_event "$TMP_DIR/popular_headers.txt" "$TMP_DIR/popular_body.json" "Popular Event ${CASE_SUFFIX}" "$POPULAR_START" "$POPULAR_END"
create_event "$TMP_DIR/niche_headers.txt" "$TMP_DIR/niche_body.json" "Niche Event ${CASE_SUFFIX}" "$NICHE_START" "$NICHE_END"
POPULAR_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$TMP_DIR/popular_body.json" | head -1)"
NICHE_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$TMP_DIR/niche_body.json" | head -1)"
[ -n "$POPULAR_ID" ] || { echo "ASSERTION_FAILED: expected popular event id"; exit 1; }
[ -n "$NICHE_ID" ] || { echo "ASSERTION_FAILED: expected niche event id"; exit 1; }

idx=1
while [ "$idx" -le 7 ]; do
  create_registration "$TMP_DIR/pop_reg_${idx}_headers.txt" "$TMP_DIR/pop_reg_${idx}_body.json" "$POPULAR_ID" "Popular User ${idx} ${CASE_SUFFIX}" "popular-${idx}-${CASE_SUFFIX}@example.com"
  idx=$((idx + 1))
done
create_registration "$TMP_DIR/niche_reg_headers.txt" "$TMP_DIR/niche_reg_body.json" "$NICHE_ID" "Niche User ${CASE_SUFFIX}" "niche-${CASE_SUFFIX}@example.com"

# When
echo "STEP: When — fetch dashboard events list"
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
echo "STEP: Then — assert registrationCount is accurate per event"
[ "$HTTP_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${HTTP_CODE}"; exit 1; }
grep -F "\"id\":\"${POPULAR_ID}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected popular event in response"; exit 1; }
grep -F "\"id\":\"${NICHE_ID}\"" "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected niche event in response"; exit 1; }
grep -F '"registrationCount":7' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount 7 in response"; exit 1; }
grep -F '"registrationCount":1' "$RESPONSE_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected registrationCount 1 in response"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no delete/reset endpoint exists for in-memory events and registrations"

echo "CODEVALID_TEST_ASSERTION_OK:registration_count_accuracy"
