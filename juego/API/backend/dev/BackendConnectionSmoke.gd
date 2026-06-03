extends Node

## Usuario de prueba. No usar datos reales.
const DEMO_USERNAME := "smoketest_user"
const DEMO_PASSWORD := "smoketest_demo_1234"
const DEMO_NAME     := "Smoke Test"
const DEMO_MAIL     := "smoketest@evidente.local"

var _api: BackendApiClient
var _session: AuthSession


func _ready() -> void:
	_api = BackendApiClient.new()
	add_child(_api)      # requerido para que HTTPRequest funcione
	_session = AuthSession.new()

	# Diferir un frame para que el árbol de escena esté listo
	_run_smoke.call_deferred()


func _run_smoke() -> void:
	print("[SMOKE] ══════════════════════════════════════")
	print("[SMOKE] Prueba de conexión backend E-VIDENTE")
	print("[SMOKE] Base URL: ", _api.base_url)
	print("[SMOKE] ══════════════════════════════════════")

	# ── Paso 1: Login (con fallback a register) ───────────────────────────
	print("[SMOKE] Paso 1 — login con usuario demo")
	var login_res := await _api.login(DEMO_USERNAME, DEMO_PASSWORD)
	print("[SMOKE] login -> ", login_res)

	if not login_res.get("ok", false):
		print("[SMOKE] Login fallido. Intentando register primero...")
		var reg_res := await _api.register(
			DEMO_USERNAME, DEMO_NAME, DEMO_MAIL, DEMO_PASSWORD
		)
		print("[SMOKE] register -> ", reg_res)
		if not reg_res.get("ok", false):
			push_error("[SMOKE] ERROR: No se pudo registrar. ¿El backend está corriendo en %s?" % _api.base_url)
			return

		login_res = await _api.login(DEMO_USERNAME, DEMO_PASSWORD)
		print("[SMOKE] login post-register -> ", login_res)
		if not login_res.get("ok", false):
			push_error("[SMOKE] ERROR: Login falló incluso después de registrar.")
			return

	var token: String = login_res.get("data", {}).get("accessToken", "")
	_session.set_session(token, DEMO_USERNAME)
	print("[SMOKE] Sesión activa: ", _session.is_logged_in())

	# ── Paso 2: GET /auth/me ──────────────────────────────────────────────
	print("[SMOKE] Paso 2 — get_me")
	var me_res := await _api.get_me(token)
	print("[SMOKE] get_me -> ", me_res)

	# ── Paso 3: RunSummary fake ───────────────────────────────────────────
	print("[SMOKE] Paso 3 — armar RunSummary fake")
	var run_summary := RunSummaryBuilder.build(
		"sin_restriccion",  # restriction
		"nodo_smoke_01",    # node_id
		"completar",        # game_type
		100,                # score
		85.0,               # accuracy
		8,                  # correct_answers
		2,                  # wrong_answers
		50,                 # exp_to_add
		true,               # completed
		42,                 # duration_seconds
	)
	print("[SMOKE] RunSummary -> ", run_summary)

	# ── Paso 4: POST /player/me/progress ─────────────────────────────────
	print("[SMOKE] Paso 4 — save_progress")
	var save_res := await _api.save_progress(token, run_summary)
	print("[SMOKE] save_progress -> ", save_res)

	# ── Paso 5: GET /player/me/progress ──────────────────────────────────
	print("[SMOKE] Paso 5 — get_progress")
	var progress_res := await _api.get_progress(token)
	print("[SMOKE] get_progress -> ", progress_res)

	print("[SMOKE] ══════════════════════════════════════")
	print("[SMOKE] Smoke completo.")
	print("[SMOKE] ══════════════════════════════════════")
