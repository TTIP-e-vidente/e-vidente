#!/bin/sh

set -eu

append_summary() {
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
	fi
}


check_required_docs() {
	echo "Checking docs and wiki baseline..."
	for file_path in $required_docs; do
		if [ -f "$file_path" ] && [ -s "$file_path" ]; then
			echo "OK: $file_path"
		else
			echo "::error::Missing or empty docs file: $file_path"
			missing=1
		fi
	done
}

missing=0

required_docs="
README.md
wiki/Home.md
wiki/Como-Empezar.md
wiki/CI.md
wiki/Arquitectura-General.md
wiki/Bitacora.md
"

check_required_docs

if [ "$missing" -ne 0 ]; then
	append_summary "### Docs / Tracking"
	append_summary "- Estado: FAIL"
	append_summary "- Motivo: falta documentacion base o algun archivo esta vacio."
	exit 1
fi

append_summary "### Docs / Tracking"
append_summary "- Estado: OK"
append_summary "- Cobertura: presencia minima de README y wiki base"

echo "Docs guardrails passed."