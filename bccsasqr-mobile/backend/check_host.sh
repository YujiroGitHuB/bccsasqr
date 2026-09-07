#!/usr/bin/env bash
# Does your host let the app talk to /api/v1?
#
#   ./check_host.sh https://your-domain.example/bccsasqr/api/v1 [API_KEY]
#
# Pass the API ROOT — the same value you give the app as
# --dart-define=API_BASE_URL — not a single script.
#
# A working API answers with JSON in the envelope {"success":…}. A free host
# that blocks non-browser requests answers with HTML carrying a JavaScript
# cookie challenge instead; a mobile app cannot pass that, and it is the one
# failure worth finding before you build an APK.

set -u
BASE="${1:?usage: check_host.sh <api-root-url> [api-key]}"
KEY="${2:-}"

# Trailing slashes are easy to paste in and would produce //health.
BASE="${BASE%/}"

hit() {
  curl -sS -m 20 -H 'Accept: application/json' \
    ${KEY:+-H "X-API-Key: $KEY"} \
    -w '\n---HTTP:%{http_code}---\n' \
    "$1" 2>&1
}

echo "GET $BASE/health"
BODY=$(hit "$BASE/health")
echo "$BODY" | head -30
echo

# Hosts without mod_rewrite serve nothing at the pretty URL. The API answers on
# index.php too, so tell the difference rather than calling the host blocked.
if echo "$BODY" | grep -qi '<html' && ! echo "$BODY" | grep -qi 'document\.cookie\|__test\|aes\.js\|toNumbers'; then
  echo "Retrying without the URL rewrite: $BASE/index.php/health"
  BODY=$(hit "$BASE/index.php/health")
  echo "$BODY" | head -30
  echo
  REWRITE_OFF=1
else
  REWRITE_OFF=0
fi

if echo "$BODY" | grep -qi 'document\.cookie\|__test\|aes\.js\|toNumbers'; then
  echo "RESULT: BLOCKED — the host returned a JavaScript anti-bot challenge."
  echo "        A mobile app cannot pass this. Move the API to another host."
elif echo "$BODY" | grep -q '"success"'; then
  if [ "$REWRITE_OFF" = "1" ]; then
    echo "RESULT: OK, but mod_rewrite is off."
    echo "        Use API_BASE_URL=$BASE/index.php"
  else
    echo "RESULT: OK — the endpoint returned JSON."
    echo "        Use API_BASE_URL=$BASE"
  fi

  # "database": false means PHP is fine but includes/db_connect.php cannot
  # reach MySQL — a different problem from a blocked host, and worth naming.
  if echo "$BODY" | grep -q '"database":[[:space:]]*false'; then
    echo "        WARNING: PHP answered but the database did not. Check"
    echo "        includes/db_connect.php credentials on this host."
  fi
elif echo "$BODY" | grep -qi '<html'; then
  echo "RESULT: BLOCKED or WRONG URL — got an HTML page instead of JSON."
  echo "        Check that $BASE points at the api/v1 folder."
else
  echo "RESULT: Unclear. Read the body above."
fi
