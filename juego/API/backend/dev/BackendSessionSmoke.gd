extends Node

const DEMO_USERNAME := "bssm_user"
const DEMO_PASSWORD := "bssm_demo_1234"
const DEMO_NAME     := "BackendSession Smoke"
const DEMO_MAIL     := "bssm@evidente.local"


func _ready() -> void:
	# Conectar señales del Autoload para capturar eventos async
	BackendSession.login_succeeded.connect(_on_login_succeeded)
	BackendSession.login_failed.connect(_on_login_failed)
	BackendSession.sync_succeeded.connect(_on_sync_succeeded)
	BackendSession.sync_failed.connect(_on_sync_failed)
	BackendSession.session_expired.connect(_on_session_expired)
	BackendSession.logout_completed.connect(_on_logout_completed)

	_run_smoke.call_deferred()


func _run_smoke() -> void:
	print("[BSSM] ══════════════════════════════════════")
	print("[BSSM] BackendSession Smoke — E-VIDENTE")
	print("[BSSM] ══════════════════════════════════════")

	# ── Paso 1: Login (con fallback a register) ───────────────────────────
	print("[BSSM] Paso 1 — login con usuario demo")
	var login_result := await BackendSession.login(DEMO_USERNAME, DEMO_PASSWORD)

	if not BackendSession.is_logged_in():
		print("[BSSM] Login fallido, intentando register...")
		var reg_result := await BackendSession.register(
			DEMO_USERNAME, DEMO_NAME, DEMO_MAIL, DEMO_PASSWORD
		)
		if not BackendSession.is_logged_in():
			push_error(
				"[BSSM] ERROR: No se pudo crear sesión. ¿El backend está corriendo? " +
				"Resultado: %s" % str(reg_result)
			)
			return

	print("[BSSM] is_logged_in: ", BackendSession.is_logged_in())
	print("[BSSM] username: ", BackendSession.get_username())

	# ── Paso 2: GET /auth/me ──────────────────────────────────────────────
	print("[BSSM] Paso 2 — get_me")
	var me_result := await BackendSession.get_me()
	print("[BSSM] get_me -> ok:", me_result.get("ok"), " status:", me_result.get("status"))

	# ── Paso 3: RunSummary fake ───────────────────────────────────────────
	print("[BSSM] Paso 3 — RunSummary fake")
	var summary := RunSummaryBuilder.build(
		"sin_restriccion",
		"nodo_bssm_01",
		"completar",
		120,
		90.0,
		9,
		1,
		60,
		true,
		38,
	)
	print("[BSSM] summary.nodeId: ", summary.get("nodeId"))
	print("[BSSM] summary.finishedAt: ", summary.get("finishedAt"))

	# ── Paso 4: save_progress ─────────────────────────────────────────────
	print("[BSSM] Paso 4 — save_progress")
	var save_result := await BackendSession.save_progress(summary)
	print("[BSSM] save_progress -> ok:", save_result.get("ok"), " status:", save_result.get("status"))

	# ── Paso 5: get_progress ──────────────────────────────────────────────
	print("[BSSM] Paso 5 — get_progress")
	var progress_result := await BackendSession.get_progress()
	print("[BSSM] get_progress -> ok:", progress_result.get("ok"), " status:", progress_result.get("status"))

	# ── Paso 6: logout ────────────────────────────────────────────────────
	print("[BSSM] Paso 6 — logout")
	BackendSession.logout()

	print("[BSSM] ══════════════════════════════════════")
	print("[BSSM] Smoke completo.")
	print("[BSSM] ══════════════════════════════════════")


# ── Handlers de señales (para loggear eventos async) ────────────────────────

func _on_login_succeeded(user: Dictionary) -> void:
	print("[BSSM] >> login_succeeded: ", user)


func _on_login_failed(reason: String) -> void:
	push_error("[BSSM] >> login_failed: " + reason)


func _on_sync_succeeded(progress: Dictionary) -> void:
	print("[BSSM] >> sync_succeeded — completed_nodes: ",
		progress.get("completedNodesCount", "n/a"))


func _on_sync_failed(reason: String) -> void:
	push_error("[BSSM] >> sync_failed: " + reason)


func _on_session_expired() -> void:
	push_error("[BSSM] >> session_expired: token vencido o inválido")


func _on_logout_completed() -> void:
	print("[BSSM] >> logout_completed. is_logged_in: ", BackendSession.is_logged_in())
