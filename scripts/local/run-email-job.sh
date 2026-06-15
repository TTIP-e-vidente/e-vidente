#!/usr/bin/env sh
# Ejecuta jobs de email con Postgres local (docker compose) + .env en BACKEND/.
# Uso: sh scripts/local/run-email-job.sh streaks|retry-failed

set -eu

JOB="${1:-}"
if [ -z "$JOB" ]; then
	echo "Usage: run-email-job.sh <streaks|retry-failed>" >&2
	exit 1
fi

case "$JOB" in
	streaks) NPM_SCRIPT="email:streaks" ;;
	retry-failed) NPM_SCRIPT="email:retry-failed" ;;
	*)
		echo "Unsupported job: $JOB" >&2
		exit 1
		;;
esac

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
	ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fi
BACKEND="${ROOT}/BACKEND"

if [ ! -f "${BACKEND}/package.json" ]; then
	echo "BACKEND/ not found under ${ROOT}" >&2
	exit 1
fi

if [ ! -f "${BACKEND}/.env" ]; then
	echo "Missing ${BACKEND}/.env" >&2
	exit 1
fi

cd "${BACKEND}"
echo "[email-local] Starting postgres if needed..."
docker compose up -d postgres

echo "[email-local] Running npm run ${NPM_SCRIPT}..."
npm run "${NPM_SCRIPT}"

echo "[email-local] OK (${JOB})"
