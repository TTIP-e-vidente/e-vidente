# HUD del mapa: racha (arriba-izquierda), ProfileButton (arriba-derecha), bloque EXP.
extends CanvasLayer

signal back_requested

const MAP_SCENE_PATH := "res://mapas/MapScene.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const RUBIK_FONT := preload("res://fonts/Rubik-VariableFont_wght.ttf")
const RUBIK_SPRAY_FONT := preload("res://fonts/RubikSprayPaint-Regular.ttf")

@onready var racha: Control = $HudRoot/RachaAnchor/Racha
@onready var profile_button: Button = $HudRoot/TopRightAnchor/ProfileButton
@onready var profile_overlay: ProfileOverlayPanel = $ProfileOverlayPanel

@onready var _map_exp_numero: Label = $HudRoot/ExpMapaAnchor/VBox/ExpNumero
@onready var _map_exp_titulo: Label = $HudRoot/ExpMapaAnchor/VBox/ExpTitle


func _ready() -> void:
	_ocultar_superposicion_perfil()
	_conectar_insignia_racha()
	_conectar_senales_guardado()
	_conectar_senales_sync()
	if is_instance_valid(profile_overlay):
		profile_overlay.ranking_pressed.connect(_on_superposicion_ranking_presionado)
		profile_overlay.login_pressed.connect(_on_superposicion_login_presionado)
	_actualizar_hud()
	_aplicar_fuentes_exp()
	call_deferred("_procesar_deep_link_leaderboard")


func _procesar_deep_link_leaderboard() -> void:
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(self)


func _aplicar_fuentes_exp() -> void:
	if is_instance_valid(_map_exp_numero):
		_map_exp_numero.add_theme_font_override("font", RUBIK_SPRAY_FONT)
		_map_exp_numero.add_theme_font_size_override("font_size", 30)
	if is_instance_valid(_map_exp_titulo):
		_map_exp_titulo.add_theme_font_override("font", RUBIK_SPRAY_FONT)
		_map_exp_titulo.add_theme_font_size_override("font_size", 24)


func _exit_tree() -> void:
	_desconectar_senales_guardado()
	_desconectar_senales_sync()


func _save_manager_listo() -> bool:
	return SaveManager != null and SaveManager.has_method("cargar_datos")


func _conectar_senales_guardado() -> void:
	if not _save_manager_listo():
		return
	var sm: Node = SaveManager
	if not sm.is_connected("save_status_changed", _al_cambiar_estado_guardado):
		sm.connect("save_status_changed", _al_cambiar_estado_guardado)
	if not sm.is_connected("progress_loaded", _al_cambiar_perfil_guardado):
		sm.connect("progress_loaded", _al_cambiar_perfil_guardado)
	if not sm.is_connected("progress_saved", _al_cambiar_perfil_guardado):
		sm.connect("progress_saved", _al_cambiar_perfil_guardado)
	if not sm.is_connected("user_registered", _al_cambiar_perfil_guardado):
		sm.connect("user_registered", _al_cambiar_perfil_guardado)


func _desconectar_senales_guardado() -> void:
	if not _save_manager_listo():
		return
	var sm: Node = SaveManager
	if sm.is_connected("save_status_changed", _al_cambiar_estado_guardado):
		sm.disconnect("save_status_changed", _al_cambiar_estado_guardado)
	if sm.is_connected("progress_loaded", _al_cambiar_perfil_guardado):
		sm.disconnect("progress_loaded", _al_cambiar_perfil_guardado)
	if sm.is_connected("progress_saved", _al_cambiar_perfil_guardado):
		sm.disconnect("progress_saved", _al_cambiar_perfil_guardado)
	if sm.is_connected("user_registered", _al_cambiar_perfil_guardado):
		sm.disconnect("user_registered", _al_cambiar_perfil_guardado)


func _conectar_senales_sync() -> void:
	if not BackendSession.pending_sync_finished.is_connected(_al_cambiar_sync_pendiente):
		BackendSession.pending_sync_finished.connect(_al_cambiar_sync_pendiente)
	if not BackendSession.pending_sync_started.is_connected(_al_cambiar_sync_pendiente_count):
		BackendSession.pending_sync_started.connect(_al_cambiar_sync_pendiente_count)


func _desconectar_senales_sync() -> void:
	if BackendSession.pending_sync_finished.is_connected(_al_cambiar_sync_pendiente):
		BackendSession.pending_sync_finished.disconnect(_al_cambiar_sync_pendiente)
	if BackendSession.pending_sync_started.is_connected(_al_cambiar_sync_pendiente_count):
		BackendSession.pending_sync_started.disconnect(_al_cambiar_sync_pendiente_count)


func _al_cambiar_sync_pendiente(_synced: int = 0, _failed: int = 0) -> void:
	_actualizar_hud()


func _al_cambiar_sync_pendiente_count(_count: int = 0) -> void:
	_actualizar_hud()


func _actualizar_hud() -> void:
	if racha != null and racha.has_method("renderizar"):
		racha.call("renderizar")
	if profile_button != null and profile_button.has_method("refrescar_icono_perfil"):
		profile_button.call("refrescar_icono_perfil")
	if profile_overlay != null and profile_overlay.visible:
		profile_overlay.refrescar()
	_actualizar_bloque_exp_mapa()


func _conectar_insignia_racha() -> void:
	if racha == null or not racha.has_signal("pressed"):
		return
	var callback := Callable(self, "_on_racha_presionado")
	if not racha.is_connected("pressed", callback):
		racha.connect("pressed", callback)


func _on_boton_perfil_presionado() -> void:
	_mostrar_superposicion_perfil()


func _on_racha_presionado() -> void:
	var ruta_escena_actual: String = _obtener_ruta_escena_retorno()
	if ruta_escena_actual == GameSceneRouter.STREAK_SCENE_PATH:
		return
	_ocultar_superposicion_perfil()
	GameSceneRouter.ir_a_racha(get_tree(), ruta_escena_actual)


func _on_boton_atras_presionado() -> void:
	back_requested.emit()


func _on_superposicion_cerrar_solicitado() -> void:
	_ocultar_superposicion_perfil()


func _on_superposicion_reanudar_presionado() -> void:
	_ocultar_superposicion_perfil()
	if not _save_manager_listo() or not SaveManager.puede_reanudar_guardado_actual():
		return
	var estado_reanudacion: Dictionary = SaveManager.recargar_desde_disco_y_obtener_reanudacion()
	GameSceneRouter.ir_a_reanudar(get_tree(), estado_reanudacion, _obtener_ruta_escena_retorno())


func _on_superposicion_edit_perfil_presionado() -> void:
	if _save_manager_listo():
		SaveManager.guardar_progreso_en_disco()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, _obtener_ruta_escena_retorno())
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_superposicion_guardar_presionado() -> void:
	_actualizar_hud()


func _on_superposicion_logout_presionado() -> void:
	await AuthApi.cerrar_sesion()
	_ocultar_superposicion_perfil()
	GameSceneRouter.go_to_main_menu(get_tree())


func _on_superposicion_ranking_presionado(scope: String = "") -> void:
	_ocultar_superposicion_perfil()
	var scope_final := scope.strip_edges()
	if scope_final.is_empty():
		scope_final = LeaderboardOverlayHelper.scope_desde_arbol(get_tree())
	LeaderboardOverlayHelper.abrir(get_tree(), scope_final)


func _on_superposicion_login_presionado() -> void:
	_ocultar_superposicion_perfil()
	var helper := AuthLoginOverlayHelper.new()
	await helper.mostrar_y_esperar(self, AuthLoginOverlayHelper.FLUJO_PERFIL)
	if AuthApi.esta_logueado():
		profile_overlay.refrescar()
		profile_overlay.mostrar_superposicion()
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(self)


func _on_superposicion_reiniciar_presionado() -> void:
	if _save_manager_listo():
		var result: Dictionary = await SaveManager.reiniciar_todo_progreso()
		if not result.get("ok", false):
			if is_instance_valid(profile_overlay):
				profile_overlay.mostrar_feedback_reset(
					str(result.get("message", "No se pudo reiniciar el progreso.")),
					false
				)
			return
		_actualizar_hud()
		if is_instance_valid(profile_overlay):
			profile_overlay.refrescar()
			profile_overlay.mostrar_feedback_reset(
				str(result.get("message", "Progreso reiniciado.")),
				true
			)
		var map_scene := get_tree().current_scene
		if map_scene != null and map_scene.has_method("actualizar_estados_de_nodos"):
			map_scene.call("actualizar_estados_de_nodos")
		return
	_ocultar_superposicion_perfil()
	GameSceneRouter.go_to_mode_selector(get_tree())


func _al_cambiar_estado_guardado(_status: Dictionary) -> void:
	_actualizar_hud()


func _al_cambiar_perfil_guardado(_profile: Dictionary) -> void:
	_actualizar_hud()


func _actualizar_bloque_exp_mapa() -> void:
	if not is_instance_valid(_map_exp_numero):
		return
	var total_exp: int = 0
	if _save_manager_listo():
		total_exp = SaveManager.obtener_exp_total()
	_map_exp_numero.text = str(total_exp)


func _mostrar_superposicion_perfil() -> void:
	profile_button.visible = false
	profile_overlay.mostrar_superposicion()


func _ocultar_superposicion_perfil() -> void:
	profile_button.visible = true
	profile_overlay.ocultar_superposicion()


func _obtener_ruta_escena_retorno() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return MAP_SCENE_PATH
	var ruta_escena: String = str(get_tree().current_scene.scene_file_path).strip_edges()
	return ruta_escena if not ruta_escena.is_empty() else MAP_SCENE_PATH
