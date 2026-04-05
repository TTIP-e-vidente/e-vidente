#!/bin/sh

set -eu

run_godot_validation() {
	godot_cmd="${1:-godot}"

	"$godot_cmd" --headless --path project --editor --quit
	"$godot_cmd" --headless --path project -s res://tests/save_manager_smoke_test.gd
	"$godot_cmd" --headless --path project -s res://tests/save_manager_validation_test.gd
	"$godot_cmd" --headless --path project -s res://tests/save_manager_signal_contract_test.gd
	"$godot_cmd" --headless --path project -s res://tests/save_manager_legacy_migration_test.gd
	"$godot_cmd" --headless --path project -s res://tests/archivero_overlay_test.gd
	"$godot_cmd" --headless --path project -s res://tests/intro_menu_profile_test.gd
	"$godot_cmd" --headless --path project -s res://tests/level_quick_save_test.gd
}


if [ "${1:-}" = "--run" ]; then
	shift
	run_godot_validation "$@"
fi