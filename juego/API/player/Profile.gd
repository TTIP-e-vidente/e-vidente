extends Control

signal close_requested()

@onready var _label_username: Label = $CenterContainer/PanelContainer/VBoxContainer/LabelUsername
@onready var _label_exp: Label = $CenterContainer/PanelContainer/VBoxContainer/LabelExp
@onready var _label_streak: Label = $CenterContainer/PanelContainer/VBoxContainer/LabelStreak
@onready var _label_best_streak: Label = $CenterContainer/PanelContainer/VBoxContainer/LabelBestStreak
@onready var _label_completed_games: Label = $CenterContainer/PanelContainer/VBoxContainer/LabelCompletedGames
@onready var _label_completed_nodes: Label = $CenterContainer/PanelContainer/VBoxContainer/LabelCompletedNodes
@onready var _label_recent_sessions: Label = $CenterContainer/PanelContainer/VBoxContainer/LabelRecentSessions
@onready var _label_status: Label = $CenterContainer/PanelContainer/VBoxContainer/LabelStatus


func _ready() -> void:
	$CenterContainer/PanelContainer/VBoxContainer/ButtonRefresh.pressed.connect(_on_boton_actualizar_pressed)
	$CenterContainer/PanelContainer/VBoxContainer/ButtonClose.pressed.connect(_on_boton_cerrar_pressed)
	var btn_logout = $CenterContainer/PanelContainer/VBoxContainer/ButtonLogout
	if btn_logout:
		btn_logout.pressed.connect(_on_boton_cerrar_sesion_pressed)

	_limpiar_etiquetas()

	if not AuthApi.esta_logueado():
		_mostrar_sin_sesion()
		return

	if AuthApi.tiene_datos_online_en_memoria():
		_mostrar_progreso_online_en_pantalla()
	else:
		_mostrar_cargando()
		cargar_y_mostrar_progreso_online()


# Solo lectura: trae progreso del servidor y lo muestra. No guarda nada local.
func cargar_y_mostrar_progreso_online() -> void:
	if not AuthApi.esta_logueado():
		_mostrar_sin_sesion()
		return

	if AuthApi.tiene_datos_online_en_memoria():
		_mostrar_progreso_online_en_pantalla()
		return

	_mostrar_cargando()
	var resultado := await AuthApi.cargar_datos_online()
	if resultado.get("ok", false):
		_mostrar_progreso_online_en_pantalla()
		return
	_mostrar_offline_o_error(resultado)


func _mostrar_sin_sesion() -> void:
	_limpiar_etiquetas()
	_establecer_estado(
		"No hay sesión activa. Iniciá sesión para ver tu progreso online.\n"
		+ "El progreso del juego se guarda localmente en este dispositivo."
	)


func _mostrar_cargando() -> void:
	_limpiar_etiquetas()
	_establecer_estado("Cargando progreso online...")


func _mostrar_offline_o_error(resultado: Dictionary) -> void:
	_limpiar_etiquetas()
	_establecer_estado(
		"Estás offline. El progreso remoto no está disponible.\n"
		+ "Tu progreso local sigue guardado en este dispositivo.\n"
		+ AuthApi.mensaje_error(resultado, "Error desconocido")
	)


func _mostrar_progreso_online_en_pantalla() -> void:
	var usuario: Dictionary = AuthApi.obtener_usuario_online()
	var progreso: Dictionary = AuthApi.obtener_progreso_online()

	_label_username.text = "Usuario: " + str(usuario.get("username", "-"))

	var perfil_online: Dictionary = progreso.get("profile", {})
	var exp_count: int = int(perfil_online.get("exp_count", 0))
	var racha: Dictionary = progreso.get("streak", {})
	var racha_actual: int = int(racha.get("current_count", 0))
	var mejor_racha: int = int(racha.get("best_count", 0))
	var lista_progreso: Array = progreso.get("progress", [])
	var total_exp: int = 0
	var total_partidas: int = 0
	var total_nodos: int = 0
	for entrada: Dictionary in lista_progreso:
		total_exp += int(entrada.get("total_exp", 0))
		total_partidas += int(entrada.get("completed_games_count", 0))
		total_nodos += int(entrada.get("completed_nodes_count", 0))

	if total_exp == 0 and exp_count > 0:
		total_exp = exp_count

	var nodos_completados: Array = progreso.get("completedNodes", [])
	if total_nodos == 0:
		total_nodos = nodos_completados.size()

	var sesiones_recientes: Array = progreso.get(
		"recentGames", progreso.get("recentGameSessions", [])
	)

	_label_exp.text = "EXP: %d" % total_exp
	_label_streak.text = "Racha actual: %d" % racha_actual
	_label_best_streak.text = "Mejor racha: %d" % mejor_racha
	_label_completed_games.text = "Partidas completadas: %d" % total_partidas
	_label_completed_nodes.text = "Nodos completados: %d" % total_nodos
	_label_recent_sessions.text = "Últimas sesiones: %d" % sesiones_recientes.size()
	_establecer_estado("Progreso online actualizado (solo lectura).")


func _limpiar_etiquetas() -> void:
	_label_username.text = "Usuario: -"
	_label_exp.text = "EXP: -"
	_label_streak.text = "Racha actual: -"
	_label_best_streak.text = "Mejor racha: -"
	_label_completed_games.text = "Partidas completadas: -"
	_label_completed_nodes.text = "Nodos completados: -"
	_label_recent_sessions.text = "Últimas sesiones: -"


func _on_boton_actualizar_pressed() -> void:
	if not AuthApi.esta_logueado():
		_mostrar_sin_sesion()
		return
	_mostrar_cargando()
	var resultado := await AuthApi.cargar_datos_online()
	if resultado.get("ok", false):
		_mostrar_progreso_online_en_pantalla()
	else:
		_mostrar_offline_o_error(resultado)


func _on_boton_cerrar_pressed() -> void:
	close_requested.emit()
	queue_free()


func _on_boton_cerrar_sesion_pressed() -> void:
	await AuthApi.cerrar_sesion()
	_mostrar_sin_sesion()
	_establecer_estado(
		"Sesión cerrada correctamente. Tocá Cerrar para volver al menú "
		+ "y luego Jugar para loguearte con otra."
	)


func _establecer_estado(texto: String) -> void:
	print("[Profile] ", texto)
	if is_instance_valid(_label_status):
		_label_status.text = texto
