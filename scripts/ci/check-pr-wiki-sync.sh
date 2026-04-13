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

doc_sensitive_changes="$(
	printf '%s\n' "$changed_files" |
		grep -E '^(\.github/workflows/|scripts/|project/(interface|niveles|resources)/.*\.(gd|tscn|tres)|project/project\.godot)$' || true
)"

if [ -z "$doc_sensitive_changes" ]; then
	echo "No architecture-sensitive changes detected."
	append_summary "### Docs / Wiki"
	append_summary "- Estado: OK"
	append_summary "- Cobertura: este PR no toca zonas que requieran recordatorio de wiki"
	exit 0
fi

documentation_changes="$(
	printf '%s\n' "$changed_files" |
		grep -E '^(README\.md|wiki/.*\.md)$' || true
)"

if [ -n "$documentation_changes" ]; then
	echo "OK: wiki or README updated in this PR."
	append_summary "### Docs / Wiki"
	append_summary "- Estado: OK"
	append_summary "- Cobertura: el PR toca codigo/estructura sensible y tambien actualiza README o wiki"
	exit 0
fi

echo "Files that triggered the wiki reminder:"
	printf '%s\n' "$doc_sensitive_changes"

report_failure "Este PR toca codigo, estructura o CI en zonas sensibles pero no actualiza README ni wiki. Agrega una nota en wiki/ o README.md para dejar trazabilidad del cambio."