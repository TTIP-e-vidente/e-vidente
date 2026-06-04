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
	add_child(_api)
	_session = AuthSession.new()
	_ejecutar_smoke.call_deferred()


func _ejecutar_smoke() -> void:
	print("[SMOKE] ══════════════════════════════════════")
	print("[SMOKE] Prueba de conexión backend E-VIDENTE")
	print("[SMOKE] Base URL: ", _api.base_url)
	print("[SMOKE] ══════════════════════════════════════")

	print("[SMOKE] Paso 1 — iniciar sesión con usuario demo")
	var login_res := await _api.iniciar_sesion(DEMO_USERNAME, DEMO_PASSWORD)
	print("[SMOKE] iniciar_sesion -> ", login_res)

	if not login_res.get("ok", false):
		print("[SMOKE] Login fallido. Intentando registrar primero...")
		var reg_res := await _api.registrar_cuenta(
			DEMO_USERNAME, DEMO_NAME, DEMO_MAIL, DEMO_PASSWORD
		)
		print("[SMOKE] registrar_cuenta -> ", reg_res)
		if not reg_res.get("ok", false):
			push_error("[SMOKE] ERROR: No se pudo registrar. ¿El backend está corriendo en %s?" % _api.base_url)
			return

		login_res = await _api.iniciar_sesion(DEMO_USERNAME, DEMO_PASSWORD)
		print("[SMOKE] iniciar_sesion post-register -> ", login_res)
		if not login_res.get("ok", false):
			push_error("[SMOKE] ERROR: Login falló incluso después de registrar.")
			return

	var token: String = login_res.get("data", {}).get("accessToken", "")
	_session.establecer_sesion(token, DEMO_USERNAME)
	print("[SMOKE] Sesión activa: ", _session.esta_logueado())

	print("[SMOKE] Paso 2 — obtener mi usuario")
	var me_res := await _api.obtener_mi_usuario(token)
	print("[SMOKE] obtener_mi_usuario -> ", me_res)

	print("[SMOKE] Paso 3 — armar RunSummary fake")
	var run_summary := RunSummaryBuilder.construir(
		"sin_restriccion",
		"nodo_smoke_01",
		"completar",
		100,
		85.0,
		8,
		2,
		50,
		true,
		42,
	)
	print("[SMOKE] RunSummary -> ", run_summary)

	print("[SMOKE] Paso 4 — guardar progreso")
	var save_res := await _api.guardar_progreso(token, run_summary)
	print("[SMOKE] guardar_progreso -> ", save_res)

	print("[SMOKE] Paso 5 — obtener progreso")
	var progress_res := await _api.obtener_progreso(token)
	print("[SMOKE] obtener_progreso -> ", progress_res)

	print("[SMOKE] ══════════════════════════════════════")
	print("[SMOKE] Smoke completo.")
	print("[SMOKE] ══════════════════════════════════════")
