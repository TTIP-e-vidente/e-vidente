#!/usr/bin/env sh
# Dispara internal-job en Supabase Edge (manual / CI smoke).
# Requiere:
#   SUPABASE_FUNCTIONS_URL o SUPABASE_PROJECT_REF
#   SUPABASE_ANON_KEY o SUPABASE_PUBLISHABLE_KEY
#   EMAIL_CRON_SECRET

set -eu

JOB="${1:-${EMAIL_JOB:-}}"
SUPABASE_FUNCTIONS_URL="${SUPABASE_FUNCTIONS_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
EMAIL_CRON_SECRET="${EMAIL_CRON_SECRET:-}"

if [ -z "$JOB" ]; then
	echo "Usage: trigger-email-job.sh <streak-at-risk-emails|streak-lost-emails|streak-emails|retry-failed-emails|refresh-leaderboard|outbound-emails>" >&2
	exit 1
fi

case "$JOB" in
	streak-emails|streak-at-risk-emails|streak-lost-emails|retry-failed-emails|refresh-leaderboard|outbound-emails) ;;
	*)
		echo "Unsupported job: $JOB" >&2
		exit 1
		;;
esac

if [ -z "$EMAIL_CRON_SECRET" ]; then
	echo "EMAIL_CRON_SECRET is required." >&2
	exit 1
fi

if [ -z "$SUPABASE_FUNCTIONS_URL" ] && [ -n "${SUPABASE_PROJECT_REF:-}" ]; then
	SUPABASE_FUNCTIONS_URL="https://${SUPABASE_PROJECT_REF}.supabase.co/functions/v1"
fi

if [ -z "$SUPABASE_ANON_KEY" ] && [ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ]; then
	SUPABASE_ANON_KEY="$SUPABASE_PUBLISHABLE_KEY"
fi

if [ -z "$SUPABASE_FUNCTIONS_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
	echo "Configure SUPABASE_FUNCTIONS_URL + SUPABASE_ANON_KEY (o PROJECT_REF + publishable key)." >&2
	exit 1
fi

URL="${SUPABASE_FUNCTIONS_URL%/}/internal-job"
echo "Triggering Edge ${URL} (job=${JOB})"
HTTP_CODE=$(curl -sS -o response.json -w "%{http_code}" \
	-X POST "$URL" \
	-H "Content-Type: application/json" \
	-H "apikey: ${SUPABASE_ANON_KEY}" \
	-H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
	-H "X-Job-Secret: ${EMAIL_CRON_SECRET}" \
	-d "{\"job\":\"${JOB}\"}")
cat response.json
echo ""
echo "HTTP ${HTTP_CODE}"
if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
	exit 1
fi
