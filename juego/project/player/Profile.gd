## Profile.gd
##
## Pantalla mínima de perfil del jugador con datos reales del backend.
##
## Muestra: username, EXP, racha actual, mejor racha, partidas completadas,
## nodos completados, sesiones recientes.
##
## Backend opcional — si no hay sesión o el servidor está apagado, muestra
## un mensaje de error controlado y no crashea.
##
## NO toca SaveManager, RunSummarySyncAdapter, minijuegos, mapas ni HUD.

extends Control

signal close_requested()

@onready var _label_username:        Label  = $CenterContainer/PanelContainer/VBoxContainer/LabelUsername
@onready var _label_exp:             Label  = $CenterContainer/PanelContainer/VBoxContainer/LabelExp
@onready var _label_streak:          Label  = $CenterContainer/PanelContainer/VBoxContainer/LabelStreak
@onready var _label_best_streak:     Label  = $CenterContainer/PanelContainer/VBoxContainer/LabelBestStreak
@onready var _label_completed_games: Label  = $CenterContainer/PanelContainer/VBoxContainer/LabelCompletedGames
@onready var _label_completed_nodes: Label  = $CenterContainer/PanelContainer/VBoxContainer/LabelCompletedNodes
@onready var _label_recent_sessions: Label  = $CenterContainer/PanelContainer/VBoxContainer/LabelRecentSessions
@onready var _label_status:          Label  = $CenterContainer/PanelContainer/VBoxContainer/LabelStatus


func _ready() -> void:
	$CenterContainer/PanelContainer/VBoxContainer/ButtonRefresh.pressed.connect(_on_button_refresh_pressed)
	$CenterContainer/PanelContainer/VBoxContainer/ButtonClose.pressed.connect(_on_button_close_pressed)

	if not BackendSession.is_logged_in():
		_set_status("No hay sesión activa")
		return

	load_profile()


# ── Carga de datos ────────────────────────────────────────────────────────────

func load_profile() -> void:
	_set_status("Cargando...")

	# Llamadas paralelas no son posibles con await secuencial, pero /progress
	# incluye todo lo que necesitamos, así que solo necesitamos una llamada.
	var progress_result := await BackendSession.get_progress()

	if not progress_result.get("ok", false):
		_set_status(
			"No se pudo cargar el perfil. Podés seguir jugando offline.\n" +
			"(status %d)" % progress_result.get("status", 0)
		)
		return

	var data: Dictionary = progress_result.get("data", {})
	_populate(data)
	_set_status("Perfil actualizado")


func _populate(data: Dictionary) -> void:
	# ── user ──
	var user: Dictionary = data.get("user", {})
	_label_username.text = "Usuario: " + str(user.get("username", "-"))

	# ── profile (exp_count global) ──
	var profile: Dictionary = data.get("profile", {})
	var exp_count: int = int(profile.get("exp_count", 0))

	# ── streak ──
	var streak: Dictionary = data.get("streak", {})
	var current_streak: int = int(streak.get("current_count", 0))
	var best_streak: int    = int(streak.get("best_count", 0))

	# ── progress (array por restriction) — sumar totales ──
	var progress_list: Array = data.get("progress", [])
	var total_exp: int            = 0
	var total_games: int          = 0
	var total_nodes: int          = 0
	for entry: Dictionary in progress_list:
		total_exp   += int(entry.get("total_exp", 0))
		total_games += int(entry.get("completed_games_count", 0))
		total_nodes += int(entry.get("completed_nodes_count", 0))

	# Usar profile.exp_count si progress está vacío (usuario sin partidas)
	if total_exp == 0 and exp_count > 0:
		total_exp = exp_count

	# ── completedNodes (list) ──
	var completed_nodes: Array = data.get("completedNodes", [])
	if total_nodes == 0:
		total_nodes = completed_nodes.size()

	# ── recentGameSessions ──
	var recent_sessions: Array = data.get("recentGameSessions", [])

	# ── Actualizar labels ──
	_label_exp.text             = "EXP: %d" % total_exp
	_label_streak.text          = "Racha actual: %d" % current_streak
	_label_best_streak.text     = "Mejor racha: %d" % best_streak
	_label_completed_games.text = "Partidas completadas: %d" % total_games
	_label_completed_nodes.text = "Nodos completados: %d" % total_nodes
	_label_recent_sessions.text = "Últimas sesiones: %d" % recent_sessions.size()


# ── Botones ───────────────────────────────────────────────────────────────────

func _on_button_refresh_pressed() -> void:
	if not BackendSession.is_logged_in():
		_set_status("No hay sesión activa")
		return
	load_profile()


func _on_button_close_pressed() -> void:
	close_requested.emit()
	queue_free()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_status(texto: String) -> void:
	print("[Profile] ", texto)
	if is_instance_valid(_label_status):
		_label_status.text = texto
