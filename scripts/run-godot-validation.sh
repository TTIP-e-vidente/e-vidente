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

	rm -f "$tmp_log"

	if [ "$status" -ne 0 ]; then
		failure_detail="$(grep -E 'FAILED:|FALLO:|Error:' "$tmp_log" | tail -n 1 || true)"
		if [ -n "$LOG_DIR" ]; then
			printf '%s\n' "$step_id" > "$LOG_DIR/last_failed_step_id"
		fi
		echo ""
		echo "FALLO: $label"
		echo "Ayuda: $failure_hint"
		if [ -n "$failure_detail" ]; then
			echo "Detalle: $failure_detail"
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
		fi
		append_summary "### Validation failed"
		append_summary "- Paso: $label"
		append_summary "- Ayuda: $failure_hint"
		if [ -n "$failure_detail" ]; then
			append_summary "- Detalle: $failure_detail"
		fi
		if [ -n "$LOG_DIR" ]; then
			append_summary "- Revisar artifact de logs de validacion para el detalle completo."
		fi
		return "$status"
	fi

	echo "OK: $label"
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

run_full_suite() {
	run_step "01-import-headless" "Import headless" "Godot no pudo importar el proyecto en modo headless. Revisar errores de parseo, rutas res:// o autoloads." --headless --path project --editor --quit
	run_step "02-content-catalog-validation" "Content catalog validation test" "Fallo la integridad del catalogo de contenido. Revisar tracks, capitulos, corridas y recursos res:// referenciados." --headless --path project -s res://tests/content_catalog_validation_test.gd
	run_step "03-save-manager-smoke" "Save manager smoke test" "El smoke test basico de guardado fallo. Revisar persistencia minima y carga inicial de SaveManager." --headless --path project -s res://tests/save_manager_smoke_test.gd
	run_step "04-save-manager-validation" "Save manager validation test" "Fallo una validacion de perfil o persistencia local. Revisar el contrato de datos que usa SaveManager." --headless --path project -s res://tests/save_manager_validation_test.gd
	run_step "05-save-manager-signal-contract" "Save manager signal contract test" "Se rompio el contrato de señales de SaveManager. Revisar nombres de señales, payloads y puntos de emision." --headless --path project -s res://tests/save_manager_signal_contract_test.gd
	run_step "06-save-manager-legacy-migration" "Save manager legacy migration test" "Fallo la migracion desde saves legacy. Revisar compatibilidad con datos viejos y creacion de session/resume." --headless --path project -s res://tests/save_manager_legacy_migration_test.gd
	run_step "07-archivero-overlay" "Archivero overlay test" "Se rompio el flujo del overlay de Archivero. Revisar nodos, visibilidad o callbacks del panel de perfil." --headless --path project -s res://tests/archivero_overlay_test.gd
	run_step "08-intro-menu-profile" "Intro menu profile test" "Fallo el flujo del menu de inicio relacionado con perfil o continuar partida. Revisar intro.gd e intro.tscn." --headless --path project -s res://tests/intro_menu_profile_test.gd
	run_step "09-level-quick-save" "Level quick save test" "Fallo el quick save dentro de niveles. Revisar persistencia parcial de items, restauracion y UI de guardado." --headless --path project -s res://tests/level_quick_save_test.gd

	write_success_summary "full" "import headless + 8 tests headless"
}

run_pr_fast_suite() {
	run_step "01-content-catalog-validation" "Content catalog validation test" "Fallo la integridad minima del catalogo de contenido. Revisar tracks, capitulos y recursos res:// referenciados." --headless --path project -s res://tests/content_catalog_validation_test.gd
	run_step "02-save-manager-smoke" "Save manager smoke test" "El smoke test basico de guardado fallo. Revisar persistencia minima y carga inicial de SaveManager." --headless --path project -s res://tests/save_manager_smoke_test.gd
	run_step "03-save-manager-signal-contract" "Save manager signal contract test" "Se rompio el contrato de señales de SaveManager. Revisar nombres de señales, payloads y puntos de emision." --headless --path project -s res://tests/save_manager_signal_contract_test.gd

	write_success_summary "pr-fast" "3 tests headless"
}

run_godot_validation() {
	mode="${1:-full}"
	GODOT_CMD="${2:-godot}"
	LOG_DIR="${EVIDENTE_VALIDATION_LOG_DIR:-}"
	COMBINED_LOG=""

	if [ -n "$LOG_DIR" ]; then
		mkdir -p "$LOG_DIR"
		COMBINED_LOG="$LOG_DIR/validation.log"
		: > "$COMBINED_LOG"
		rm -f "$LOG_DIR/last_failed_step_id"
	fi

	case "$mode" in
		full)
			run_full_suite
			;;
		pr-fast)
			run_pr_fast_suite
			;;
		*)
			echo "Modo de validacion no soportado: $mode" >&2
			exit 1
			;;
	esac
}


if [ "${1:-}" = "--run" ]; then
	shift
	mode="full"
	case "${1:-}" in
		full|pr-fast)
			mode="$1"
			shift
			;;
	esac
	run_godot_validation "$mode" "${1:-godot}"
fi