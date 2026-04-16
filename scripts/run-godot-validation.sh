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
		--headless --path project --editor --quit
}


run_gameplay_smoke() {
	run_step \
		"03-vertical-slice-smoke" \
		"Gameplay smoke test" \
		"Se rompio el flujo minimo Splash -> Intro -> Selector -> Archivero -> Libro -> Gameplay." \
		--headless --path project -s res://tests/vertical_slice_smoke_test.gd
}


run_codebase_suite() {
	run_import_headless

	write_success_summary \
		"codebase" \
		"import headless"
}


run_smoke_suite() {
	run_import_headless
	run_gameplay_smoke

	write_success_summary \
		"smoke" \
		"import headless + gameplay smoke"
}


run_ci_suite() {
	run_import_headless
	run_gameplay_smoke

	write_success_summary \
		"ci" \
		"import headless + gameplay smoke"
}


run_full_suite() {
	run_import_headless
	run_gameplay_smoke

	write_success_summary \
		"full" \
		"import headless + gameplay smoke"
}

run_godot_validation() {
	mode="${1:-ci}"
	GODOT_CMD="${2:-godot}"
	LOG_DIR="${EVIDENTE_VALIDATION_LOG_DIR:-}"
	COMBINED_LOG=""

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