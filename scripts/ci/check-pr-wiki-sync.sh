#!/bin/sh

set -eu

append_summary() {
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
	fi
}

report_failure() {
	message="$1"
	echo "::error::$message"
	append_summary "### Docs / Wiki"
	append_summary "- Estado: FAIL"
	append_summary "- Motivo: $message"
	exit 1
}

if [ "${EVIDENTE_VALIDATION_CONTEXT:-}" != "pull_request" ]; then
	echo "Wiki sync reminder only runs on pull requests."
	exit 0
fi

base_ref="${EVIDENTE_PR_BASE_REF:-}"
if [ -z "$base_ref" ]; then
	report_failure "No se pudo resolver la rama base del pull request para validar wiki."
fi

changed_files="$(git diff --name-only --diff-filter=ACMR "origin/$base_ref"...HEAD)"

if [ -z "$changed_files" ]; then
	echo "No changed files detected for PR wiki sync check."
	append_summary "### Docs / Wiki"
	append_summary "- Estado: OK"
	append_summary "- Cobertura: no hay cambios diff-aware que requieran wiki en este PR"
	exit 0
fi

ci_sensitive_changes="$(
	printf '%s\n' "$changed_files" |
		grep -E '^(\.github/workflows/|scripts/ci/|scripts/run-godot-validation\.(sh|ps1))' || true
)"

project_sensitive_changes="$(
	printf '%s\n' "$changed_files" |
		grep -E '^(project/(interface|niveles|resources)/.*\.(gd|tscn|tres)|project/project\.godot)$' || true
)"

if [ -z "$ci_sensitive_changes" ] && [ -z "$project_sensitive_changes" ]; then
	echo "No documentation-sensitive changes detected."
	append_summary "### Docs / Wiki"
	append_summary "- Estado: OK"
	append_summary "- Cobertura: este PR no toca CI ni zonas sensibles que requieran recordatorio documental"
	exit 0
fi

ci_doc_changes="$(
	printf '%s\n' "$changed_files" |
		grep -E '^wiki/CI\.md$' || true
)"

documentation_changes="$(
	printf '%s\n' "$changed_files" |
		grep -E '^(README\.md|wiki/.*\.md)$' || true
)"

if [ -n "$ci_sensitive_changes" ] && [ -z "$ci_doc_changes" ]; then
	echo "Files that triggered the CI documentation reminder:"
	printf '%s\n' "$ci_sensitive_changes"
	report_failure "Este PR cambia CI o sus scripts de validacion, pero no actualiza wiki/CI.md. Agrega una nota en wiki/CI.md para dejar trazabilidad del cambio."
fi

if [ -n "$project_sensitive_changes" ] && [ -z "$documentation_changes" ]; then
	echo "Files that triggered the architecture documentation reminder:"
	printf '%s\n' "$project_sensitive_changes"
	report_failure "Este PR toca codigo o estructura sensible del proyecto, pero no actualiza README ni wiki. Agrega una nota en wiki/ o README.md para dejar trazabilidad del cambio."
fi

echo "OK: documentation reminder satisfied for this PR."
append_summary "### Docs / Wiki"
append_summary "- Estado: OK"
append_summary "- Cobertura: los cambios sensibles del PR quedaron acompanados por documentacion"
exit 0