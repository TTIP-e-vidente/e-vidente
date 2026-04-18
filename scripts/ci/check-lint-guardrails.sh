#!/bin/sh

set -eu

append_summary() {
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
	fi
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

run_eslint_if_configured

append_summary "### Lint"
append_summary "- Estado: OK"
append_summary "- Cobertura: ESLint opcional deterministico"

echo "Lint guardrails passed."
