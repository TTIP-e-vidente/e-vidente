#!/bin/sh

set -eu

append_summary() {
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
	fi
}

report_failure() {
	message="$1"
	echo "Archivos cambiados en el PR:"
	printf '%s\n' "$changed_files"
	echo "::error::$message"
	append_summary "### Docs / Tracking"
	append_summary "- Estado: FAIL"
	append_summary "- Motivo: $message"
	exit 1
}

base_ref="${EVIDENTE_PR_BASE_REF:-${GITHUB_BASE_REF:-}}"
if [ -z "$base_ref" ]; then
	echo "::error::No se pudo resolver la rama base del pull request para validar documentacion."
	exit 1
fi

changed_files="$(git diff --name-only --diff-filter=ACMR "origin/$base_ref"...HEAD)"

if [ -z "$changed_files" ]; then
	report_failure "No se detectaron archivos modificados en el diff del pull request."
fi

doc_changes="$(
	printf '%s\n' "$changed_files" |
		grep -Ei '^(README\.md|CHANGELOG\.md|docs/.*\.md|wiki/.*\.md)$' || true
)"

tracking_changes="$(
	printf '%s\n' "$changed_files" |
		grep -Ei '^(wiki/bitacora(-.*)?\.md|changelog\.md|docs/.*(bitacora|changelog).*\.md|wiki/.*changelog.*\.md)$' || true
)"

if [ -z "$doc_changes" ]; then
	report_failure "Este PR no modifica documentacion Markdown. Actualiza algun .md en docs/, wiki/ o README.md."
fi

if [ -z "$tracking_changes" ]; then
	report_failure "Este PR no actualiza bitacora ni changelog. Deja trazabilidad en wiki/Bitacora*.md (p. ej. Bitacora-Entrega-3.md), CHANGELOG.md o docs/ equivalente."
fi

append_summary "### Docs / Tracking"
append_summary "- Estado: OK"
append_summary "- Cobertura: el PR actualiza documentacion Markdown y deja traza en bitacora/changelog"

echo "PR docs guardrails passed."