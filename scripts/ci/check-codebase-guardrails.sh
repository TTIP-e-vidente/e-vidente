#!/bin/sh

set -eu

append_summary() {
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
	fi
}

report_missing_path() {
	path_kind="$1"
	required_path="$2"
	echo "::error::Missing critical $path_kind: $required_path"
	missing=1
}


check_required_directories() {
	echo "Checking critical repository directories..."
	for dir_path in $critical_dirs; do
		if [ -d "$dir_path" ]; then
			echo "OK: $dir_path"
		else
			report_missing_path "directory" "$dir_path"
		fi
	done
}


check_required_files() {
	echo "Checking critical repository files..."
	for file_path in $critical_files; do
		if [ -f "$file_path" ]; then
			echo "OK: $file_path"
		else
			report_missing_path "file" "$file_path"
		fi
	done
}

run_eslint_if_configured() {
	if [ ! -f package.json ]; then
		echo "No package.json detected. Skipping ESLint guardrail."
		return
	fi

	has_eslint_config=0
	for config_path in \
		eslint.config.js \
		eslint.config.mjs \
		.eslintrc \
		.eslintrc.json \
		.eslintrc.js \
		.eslintrc.cjs \
		.eslintrc.yaml \
		.eslintrc.yml
	do
		if [ -f "$config_path" ]; then
			has_eslint_config=1
			break
		fi
	done

	if [ "$has_eslint_config" -ne 1 ]; then
		echo "No ESLint config detected. Skipping lint guardrail."
		return
	fi

	if [ ! -f package-lock.json ] && [ ! -f npm-shrinkwrap.json ]; then
		echo "::notice::Skipping ESLint: package.json detected but no npm lockfile is pinned."
		echo "::notice::Keep lint outside the required gate until Node tooling is deterministic."
		return
	fi

	echo "Running ESLint with pinned npm dependencies..."
	npm ci
	npx eslint . --max-warnings=0
}

missing=0

critical_dirs="
.github/workflows
project
project/interface
project/niveles
project/tests
scripts
scripts/ci
wiki
"

critical_files="
.github/workflows/docs-pr.yml
.github/workflows/gameplay-smoke-pr.yml
project/project.godot
project/interface/evidente.tscn
project/niveles/intro.tscn
project/niveles/selector.tscn
project/interface/archivero.tscn
project/interface/libro.tscn
project/niveles/nivel_1/Level.tscn
project/tests/vertical_slice_smoke_test.gd
scripts/run-godot-validation.sh
scripts/run-godot-validation.ps1
scripts/ci/check-docs-guardrails.sh
scripts/ci/check-pr-docs.sh
"

check_required_directories
check_required_files

if [ "$missing" -ne 0 ]; then
	append_summary "### Codebase / Structure"
	append_summary "- Estado: FAIL"
	append_summary "- Motivo: falta estructura o entrypoints criticos del slice."
	exit 1
fi

run_eslint_if_configured

append_summary "### Codebase / Structure"
append_summary "- Estado: OK"
append_summary "- Cobertura: estructura critica del repo y lint opcional deterministico"

echo "Codebase guardrails passed."