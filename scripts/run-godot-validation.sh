#!/bin/sh

set -eu

append_summary() {
	if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
		printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
	fi
}

begin_group() {
	if [ -n "${GITHUB_ACTIONS:-}" ]; then
		printf '::group::%s\n' "$1"
	fi
}

end_group() {
	if [ -n "${GITHUB_ACTIONS:-}" ]; then
		printf '::endgroup::\n'
	fi
}

run_step() {
	step_id="$1"
	label="$2"
	failure_hint="$3"
	shift 3

	tmp_log="$(mktemp)"
	if "$GODOT_CMD" "$@" >"$tmp_log" 2>&1; then
		status=0
	else
		status=$?
	fi

	begin_group "$label"
	printf '\n==> %s\n' "$label"
	printf 'Que hace este paso: %s\n' "$failure_hint"
	printf 'Comando: %s %s\n\n' "$GODOT_CMD" "$*"
	cat "$tmp_log"
	end_group

	if [ -n "$LOG_DIR" ]; then
		cp "$tmp_log" "$LOG_DIR/$step_id.log"
		cat "$tmp_log" >> "$COMBINED_LOG"
		printf '\n\n' >> "$COMBINED_LOG"
	fi

	failure_detail="$(grep -E 'SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|FAILED:|FALLO:' "$tmp_log" | tail -n 1 || true)"
	all_errors="$(grep -n -E 'ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load' "$tmp_log" | head -n 30 || true)"
	if [ "$status" -eq 0 ] && [ -n "$failure_detail" ]; then
		status=1
	fi

	if [ "$status" -ne 0 ]; then
		failure_excerpt="$(tail -n 20 "$tmp_log" | tr '\n' '|' | sed 's/[[:space:]]\+/ /g' | cut -c1-1500)"
		echo ""
		echo "FALLO: $label"
		echo "Ayuda: $failure_hint"
		if [ -n "$failure_detail" ]; then
			echo "Detalle: $failure_detail"
		fi
		if [ -n "$all_errors" ]; then
			echo "Errores completos:"
			echo "$all_errors"
		fi
		if [ -n "$failure_excerpt" ]; then
			echo "Excerpt: $failure_excerpt"
		fi
		if [ -n "$LOG_DIR" ]; then
			echo "Log del paso: $LOG_DIR/$step_id.log"
			echo "Log completo: $COMBINED_LOG"
		fi
		if [ -n "${GITHUB_ACTIONS:-}" ]; then
			printf '::error title=%s::%s\n' "$label" "$failure_hint"
			if [ -n "$failure_detail" ]; then
				printf '::error title=%s detalle::%s\n' "$label" "$failure_detail"
			fi
			if [ -n "$failure_excerpt" ]; then
				printf '::error title=%s excerpt::%s\n' "$label" "$failure_excerpt"
			fi
		fi
		append_summary "### Validation failed"
		append_summary "- Paso: $label"
		append_summary "- Ayuda: $failure_hint"
		if [ -n "$failure_detail" ]; then
			append_summary "- Detalle: $failure_detail"
		fi
		if [ -n "$failure_excerpt" ]; then
			append_summary "- Excerpt: $failure_excerpt"
		fi
		if [ -n "$LOG_DIR" ]; then
			append_summary "- Revisar artifact de logs de validacion para el detalle completo."
		fi
		rm -f "$tmp_log"
		return "$status"
	fi

	rm -f "$tmp_log"
	echo "OK: $label"
}

godot_project_args() {
	printf '%s\n' --headless --path juego
}

preserve_local_save_files() {
	SAVE_DIR="${APPDATA:-$HOME/.local/share}/Godot/app_userdata/Evidente"
	SAVE_SNAPSHOT_DIR="$(mktemp -d)"
	for save_name in save_data.json save_data.tmp.json save_data.backup.json; do
		if [ -f "$SAVE_DIR/$save_name" ]; then
			cp "$SAVE_DIR/$save_name" "$SAVE_SNAPSHOT_DIR/$save_name"
			touch -r "$SAVE_DIR/$save_name" "$SAVE_SNAPSHOT_DIR/$save_name"
		fi
	done
}

restore_local_save_files() {
	if [ -z "${SAVE_SNAPSHOT_DIR:-}" ]; then
		return
	fi
	mkdir -p "$SAVE_DIR"
	for save_name in save_data.json save_data.tmp.json save_data.backup.json; do
		if [ -f "$SAVE_SNAPSHOT_DIR/$save_name" ]; then
			cp "$SAVE_SNAPSHOT_DIR/$save_name" "$SAVE_DIR/$save_name"
			touch -r "$SAVE_SNAPSHOT_DIR/$save_name" "$SAVE_DIR/$save_name"
		else
			rm -f "$SAVE_DIR/$save_name"
		fi
	done
	rm -rf "$SAVE_SNAPSHOT_DIR"
}

write_success_summary() {
	mode="$1"
	executed_steps="$2"

	append_summary "### Validation"
	append_summary "- Perfil: $mode"
	append_summary "- Estado: OK"
	append_summary "- Pasos ejecutados: $executed_steps"
	if [ -n "$LOG_DIR" ]; then
		append_summary "- Artifact: logs de validacion por paso y log combinado"
	fi
}

run_import_headless() {
	run_step \
		"01-import-headless" \
		"Import headless" \
		"Godot no pudo abrir el proyecto en limpio. Revisar parseo, autoloads y rutas res://." \
		$(godot_project_args) --editor --quit
}


run_gameplay_smoke() {
	if [ ! -f juego/tests/vertical_slice_smoke_test.gd ]; then
		echo "SKIP: Gameplay smoke test (juego/tests/vertical_slice_smoke_test.gd no existe)"
		return 0
	fi
	run_step \
		"03-vertical-slice-smoke" \
		"Gameplay smoke test" \
		"Se rompio el flujo minimo Splash -> Intro -> Selector -> Mapa -> Gameplay." \
		$(godot_project_args) -s res://tests/vertical_slice_smoke_test.gd
}


run_question_json_contract() {
	if [ ! -f juego/tests/node_content_loader_test.gd ]; then
		echo "SKIP: Playable node JSON contract test (juego/tests/node_content_loader_test.gd no existe)"
		return 0
	fi
	run_step \
		"02-node-json-contract" \
		"Playable node JSON contract test" \
		"Se rompio el contrato canonical de nodos jugables por JSON o su manejo de errores." \
		$(godot_project_args) -s res://tests/node_content_loader_test.gd
}


run_post_game_flow_controller() {
	if [ ! -f juego/tests/post_game_flow_controller_test.gd ]; then
		echo "SKIP: Post-game flow controller test (juego/tests/post_game_flow_controller_test.gd no existe)"
		return 0
	fi
	run_step \
		"02b-post-game-flow" \
		"Post-game flow controller test" \
		"Se rompieron las decisiones de post-partida, el adapter del router o el retorno desde racha." \
		$(godot_project_args) -s res://tests/post_game_flow_controller_test.gd
}


run_map_progress_visual() {
	if [ ! -f juego/tests/map_progress_visual_test.gd ]; then
		echo "SKIP: Map progress visual test (juego/tests/map_progress_visual_test.gd no existe)"
		return 0
	fi
	run_step \
		"02c-map-progress-visual" \
		"Map progress visual test" \
		"Se rompio el contrato del mapa de celiaquia, los estados visuales o el desbloqueo del siguiente nodo." \
		$(godot_project_args) -s res://tests/map_progress_visual_test.gd
}


run_login_scene_nodes() {
	if [ ! -f juego/tests/auth/test_login_scene_nodes.gd ]; then
		echo "SKIP: Login scene node contract test (juego/tests/auth/test_login_scene_nodes.gd no existe)"
		return 0
	fi
	run_step \
		"02d-login-scene-nodes" \
		"Login scene node contract test" \
		"Login.tscn no instancia todos los nodos del formulario o _ready falla al conectar botones." \
		$(godot_project_args) -s res://tests/auth/test_login_scene_nodes.gd
}


run_intro_login_overlay() {
	if [ ! -f juego/tests/auth/test_intro_login_overlay.gd ]; then
		echo "SKIP: Intro login overlay test (juego/tests/auth/test_intro_login_overlay.gd no existe)"
		return 0
	fi
	run_step \
		"02e-intro-login-overlay" \
		"Intro login overlay test" \
		"El menu principal no muestra el overlay de login con botones accesibles." \
		$(godot_project_args) -s res://tests/auth/test_intro_login_overlay.gd
}


run_question_json_contract() {
	if [ ! -f juego/tests/node_content_loader_test.gd ]; then
		echo "SKIP: Playable node JSON contract test (juego/tests/node_content_loader_test.gd no existe)"
		return 0
	fi
	run_step \
		"02-node-json-contract" \
		"Playable node JSON contract test" \
		"Se rompio el contrato canonical de nodos jugables por JSON o su manejo de errores." \
		--headless --path juego -s res://tests/node_content_loader_test.gd
}


run_post_game_flow_controller() {
	if [ ! -f juego/tests/post_game_flow_controller_test.gd ]; then
		echo "SKIP: Post-game flow controller test (juego/tests/post_game_flow_controller_test.gd no existe)"
		return 0
	fi
	run_step \
		"02b-post-game-flow" \
		"Post-game flow controller test" \
		"Se rompieron las decisiones de post-partida, el adapter del router o el retorno desde racha." \
		--headless --path juego -s res://tests/post_game_flow_controller_test.gd
}


run_map_progress_visual() {
	if [ ! -f juego/tests/map_progress_visual_test.gd ]; then
		echo "SKIP: Map progress visual test (juego/tests/map_progress_visual_test.gd no existe)"
		return 0
	fi
	run_step \
		"02c-map-progress-visual" \
		"Map progress visual test" \
		"Se rompio el contrato del mapa de celiaquia, los estados visuales o el desbloqueo del siguiente nodo." \
		--headless --path juego -s res://tests/map_progress_visual_test.gd
}


run_codebase_suite() {
	run_import_headless

	write_success_summary \
		"codebase" \
		"import headless"
}


run_smoke_suite() {
	run_import_headless
	run_question_json_contract
	run_post_game_flow_controller
	run_map_progress_visual
	run_login_scene_nodes
	run_intro_login_overlay
	run_gameplay_smoke

	write_success_summary \
		"smoke" \
		"import headless + tests disponibles + login + gameplay smoke"
}


run_ci_suite() {
	run_import_headless
	run_question_json_contract
	run_post_game_flow_controller
	run_map_progress_visual
	run_login_scene_nodes
	run_intro_login_overlay
	run_gameplay_smoke

	write_success_summary \
		"ci" \
		"import headless + tests disponibles + login + gameplay smoke"
}


run_full_suite() {
	run_import_headless
	run_question_json_contract
	run_post_game_flow_controller
	run_map_progress_visual
	run_login_scene_nodes
	run_intro_login_overlay
	run_gameplay_smoke

	write_success_summary \
		"full" \
		"import headless + tests disponibles + login + gameplay smoke"
}

run_godot_validation() {
	mode="${1:-ci}"
	GODOT_CMD="${2:-godot}"
	REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
	LOG_DIR="${EVIDENTE_VALIDATION_LOG_DIR:-}"
	COMBINED_LOG=""
	preserve_local_save_files
	mkdir -p "$REPO_ROOT/.godot-validation-save"
	export EVIDENTE_SAVE_DIR="$REPO_ROOT/.godot-validation-save"
	trap restore_local_save_files EXIT

	if [ -n "$LOG_DIR" ]; then
		mkdir -p "$LOG_DIR"
		COMBINED_LOG="$LOG_DIR/validation.log"
		: > "$COMBINED_LOG"
	fi

	case "$mode" in
		codebase|guardrails|technical)
			run_codebase_suite
			;;
		smoke)
			run_smoke_suite
			;;
		ci|pr-fast)
			run_ci_suite
			;;
		full)
			run_full_suite
			;;
		*)
			echo "Modo de validacion no soportado: $mode" >&2
			exit 1
			;;
	esac
}


if [ "${1:-}" = "--run" ]; then
	shift
	mode="ci"
	case "${1:-}" in
			ci|full|pr-fast|smoke|codebase|guardrails|technical)
			mode="$1"
			shift
			;;
	esac
	run_godot_validation "$mode" "${1:-godot}"
fi
