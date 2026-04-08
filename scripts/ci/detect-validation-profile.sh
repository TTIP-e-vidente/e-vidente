#!/bin/sh

set -eu

append_summary() {
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
	fi
}

write_output() {
	key="$1"
	value="$2"

	if [ -n "${GITHUB_OUTPUT:-}" ]; then
		printf '%s=%s\n' "$key" "$value" >> "$GITHUB_OUTPUT"
	fi
}

BASE_SHA=""
HEAD_SHA=""

if [ "${EVENT_NAME:-}" = "pull_request" ]; then
	BASE_SHA="${PR_BASE_SHA:-}"
	HEAD_SHA="${PR_HEAD_SHA:-}"
else
	BASE_SHA="${GITHUB_BEFORE:-}"
	HEAD_SHA="${GITHUB_SHA:-}"
fi

if [ -z "$BASE_SHA" ] || [ "$BASE_SHA" = "0000000000000000000000000000000000000000" ]; then
	BASE_SHA="HEAD~1"
fi

if [ -z "$HEAD_SHA" ]; then
	HEAD_SHA="HEAD"
fi

changed_files=$(git diff --name-only "$BASE_SHA" "$HEAD_SHA" || true)
profile="full"
reason="No se pudo determinar un diff confiable; se usa la validacion completa por seguridad."

if [ -n "$changed_files" ]; then
	if printf '%s\n' "$changed_files" | grep -Eq '^(project/|scripts/run-godot-validation\.sh|scripts/run-godot-validation\.ps1)'; then
		profile="full"
		reason="Cambios detectados en project/ o en la suite compartida de validacion."
	else
		profile="pr-fast"
		reason="Solo cambiaron docs, metadata o infraestructura fuera de project/."
	fi
fi

echo "Base SHA: $BASE_SHA"
echo "Head SHA: $HEAD_SHA"
echo "Changed files:"
if [ -n "$changed_files" ]; then
	printf '%s\n' "$changed_files"
else
	echo "(none)"
fi
echo "Validation profile: $profile"
echo "Reason: $reason"

write_output "profile" "$profile"
write_output "reason" "$reason"

append_summary "### Validation profile"
append_summary "- Perfil elegido: $profile"
append_summary "- Motivo: $reason"