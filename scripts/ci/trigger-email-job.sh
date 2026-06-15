#!/usr/bin/env sh
# Dispara un job interno de email en el backend desplegado.
# Uso: EMAIL_JOB=streak-emails BACKEND_BASE_URL=... EMAIL_CRON_SECRET=... sh scripts/ci/trigger-email-job.sh

set -eu

JOB="${1:-${EMAIL_JOB:-}}"
BACKEND_BASE_URL="${BACKEND_BASE_URL:-}"
EMAIL_CRON_SECRET="${EMAIL_CRON_SECRET:-}"

if [ -z "$JOB" ]; then
	echo "Usage: trigger-email-job.sh <streak-emails|retry-failed-emails>" >&2
	exit 1
fi

case "$JOB" in
	streak-emails|retry-failed-emails) ;;
	*)
		echo "Unsupported job: $JOB" >&2
		exit 1
		;;
esac

if [ -z "$BACKEND_BASE_URL" ]; then
	echo "BACKEND_BASE_URL is required (GitHub secret or env var)." >&2
	exit 1
fi

if [ -z "$EMAIL_CRON_SECRET" ]; then
	echo "EMAIL_CRON_SECRET is required (GitHub secret or env var)." >&2
	exit 1
fi

BASE="${BACKEND_BASE_URL%/}"
URL="${BASE}/internal/jobs/${JOB}"

echo "Triggering ${URL}"

HTTP_CODE=$(curl -sS -o response.json -w "%{http_code}" \
	-X POST "$URL" \
	-H "X-Job-Secret: ${EMAIL_CRON_SECRET}" \
	-H "Content-Type: application/json")

cat response.json
echo ""
echo "HTTP ${HTTP_CODE}"

if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -ge 300 ]; then
	exit 1
fi
