#!/bin/sh

set -eu

repo_root() {
	git rev-parse --show-toplevel
}

cd_repo_root() {
	cd "$(repo_root)"
}

print_warn() {
	printf 'Aviso: %s\n' "$1" >&2
}

print_error() {
	printf 'Error: %s\n' "$1" >&2
}

has_command() {
	command -v "$1" >/dev/null 2>&1
}

resolve_godot_cmd() {
	if has_command godot; then
		printf '%s\n' godot
		return 0
	fi

	if has_command godot4; then
		printf '%s\n' godot4
		return 0
	fi

	return 1
}

get_staged_files() {
	git diff --cached --name-only --diff-filter=ACMRD
}

get_staged_statuses() {
	git diff --cached --name-status --diff-filter=ACMRD
}