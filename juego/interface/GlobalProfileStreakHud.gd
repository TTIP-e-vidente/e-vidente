# HELPER_INTERNO
# HUD global (CanvasLayer 75) con botón de perfil y badge de racha.
extends CanvasLayer

const RACHA_SCENE := preload("res://interface/components/Racha.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")
const PROFILE_OVERLAY_SCENE := preload("res://interface/components/ProfileOverlayPanel.tscn")

const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const PROFILE_EDITOR_SCENE_PATH := "res://interface/auth.tscn"
const MAIL_NUDGE_SCENE_PATH := "res://interface/auth/MailVerifyNudge.tscn"
const SPLASH_SCENE_PATH := "res://interface/evidente.tscn"
const INTRO_SCENE_PATH := "res://niveles/intro.tscn"
const SELECTOR_SCENE_PATH := "res://niveles/selector.tscn"
const STREAK_SCENE_PATH := "res://interface/components/ProgressManagerRacha.tscn"
const RESUME_FALLBACK_SCENE := "res://niveles/selector.tscn"
# Posicion de la racha (ancla superior izquierda y offsets en pixeles)
const _RACHA_OFFSETS := Rect2(16.0, 16.0, 152.0, 152.0)

var _hud_root: Control
var _racha: Control
var _profile_button: Button
var _last_scene_path := ""
var _profile_overlay: ProfileOverlayPanel
var _mail_verify_nudge: CanvasLayer = null


func _ready() -> void:
	layer = 75
	_construir_hud()
	_profile_overlay = PROFILE_OVERLAY_SCENE.instantiate()
	add_child(_profile_overlay)
	_profile_overlay.resume_pressed.connect(_on_superposicion_reanudar_presionado)
	_profile_overlay.save_pressed.connect(_on_superposicion_guardar_presionado)
	_profile_overlay.edit_profile_pressed.connect(_on_superposicion_editar_perfil_presionado)
	_profile_overlay.reestablecer_progreso_pressed.connect(_on_superposicion_reiniciar_presionado)
	_profile_overlay.logout_pressed.connect(_on_superposicion_logout_presionado)
	_profile_overlay.ranking_pressed.connect(_on_superposicion_ranking_presionado)
	_profile_overlay.close_requested.connect(_on_superposicion_cierre_solicitado)
	_instalar_aviso_verificacion_mail()
	_conectar_senales_save_manager()
	get_tree().node_added.connect(_on_nodo_arbol_agregado)
	_refrescar_hud()


func _exit_tree() -> void:
	_desconectar_senales_save_manager()
	if get_tree() != null and get_tree().node_added.is_connected(_on_nodo_arbol_agregado):
		get_tree().node_added.disconnect(_on_nodo_arbol_agregado)


func _construir_hud() -> void:
	_hud_root = Control.new()
	_hud_root.name = "GlobalProfileRachaHudRoot"
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	_racha = RACHA_SCENE.instantiate() as Control
	if _racha != null:
		_racha.name = "GlobalRacha"
		_racha.anchor_left = 0.0
		_racha.anchor_top = 0.0
		_racha.anchor_right = 0.0
		_racha.anchor_bottom = 0.0
		_racha.offset_left = _RACHA_OFFSETS.position.x
		_racha.offset_top = _RACHA_OFFSETS.position.y
		_racha.offset_right = _RACHA_OFFSETS.size.x
		_racha.offset_bottom = _RACHA_OFFSETS.size.y
		_hud_root.add_child(_racha)
		_conectar_badge_racha()

	_profile_button = Button.new()
	_profile_button.name = "GlobalProfileButton"
	_profile_button.script = PROFILE_BUTTON_SCRIPT
	_profile_button.anchor_left = 1.0
	_profile_button.anchor_top = 1.0
	_profile_button.anchor_right = 1.0
	_profile_button.anchor_bottom = 1.0
	_profile_button.offset_left = -256.0
	_profile_button.offset_top = -84.0
	_profile_button.offset_right = -16.0
	_profile_button.offset_bottom = -16.0
	_profile_button.tooltip_text = ""
	_profile_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_profile_button.pressed.connect(_on_boton_perfil_presionado)
	_hud_root.add_child(_profile_button)


func _conectar_senales_save_manager() -> void:
	if not _save_manager_listo():
		return
	var sm: Node = SaveManager
	if not sm.is_connected("save_status_changed", _on_save_manager_cambiado):
		sm.connect("save_status_changed", _on_save_manager_cambiado)
	if not sm.is_connected("progress_loaded", _on_save_manager_perfil_cambiado):
		sm.connect("progress_loaded", _on_save_manager_perfil_cambiado)
	if not sm.is_connected("progress_saved", _on_save_manager_perfil_cambiado):
		sm.connect("progress_saved", _on_save_manager_perfil_cambiado)
	if not sm.is_connected("user_registered", _on_save_manager_perfil_cambiado):
		sm.connect("user_registered", _on_save_manager_perfil_cambiado)


func _desconectar_senales_save_manager() -> void:
	if not _save_manager_listo():
		return
	var sm: Node = SaveManager
	if sm.is_connected("save_status_changed", _on_save_manager_cambiado):
		sm.disconnect("save_status_changed", _on_save_manager_cambiado)
	if sm.is_connected("progress_loaded", _on_save_manager_perfil_cambiado):
		sm.disconnect("progress_loaded", _on_save_manager_perfil_cambiado)
	if sm.is_connected("progress_saved", _on_save_manager_perfil_cambiado):
		sm.disconnect("progress_saved", _on_save_manager_perfil_cambiado)
	if sm.is_connected("user_registered", _on_save_manager_perfil_cambiado):
		sm.disconnect("user_registered", _on_save_manager_perfil_cambiado)


func _save_manager_listo() -> bool:
	return SaveManager != null and SaveManager.has_method("cargar_datos")


func _on_nodo_arbol_agregado(_node: Node) -> void:
	call_deferred("_refrescar_hud")


func _on_save_manager_cambiado(_status: Dictionary) -> void:
	_refrescar_hud()


func _on_save_manager_perfil_cambiado(_profile: Dictionary) -> void:
	_refrescar_hud()


func _refrescar_hud() -> void:
	var scene_path := _obtener_ruta_escena_actual()
	if scene_path != _last_scene_path:
		_last_scene_path = scene_path
		_aplicar_visibilidad_escena(scene_path)
		if _profile_overlay != null and _profile_overlay.visible:
			_profile_overlay.visible = false
			_profile_button.visible = true
	if _racha != null and _racha.has_method("renderizar"):
		_racha.call("renderizar")
	if _profile_button != null and _profile_button.has_method("refrescar_icono_perfil"):
		_profile_button.call("refrescar_icono_perfil")
	_refrescar_aviso_verificacion_mail()


func _aplicar_visibilidad_escena(scene_path: String) -> void:
	var hidden_scenes := [
		PROFILE_EDITOR_SCENE_PATH,
		SPLASH_SCENE_PATH,
		INTRO_SCENE_PATH,
		SELECTOR_SCENE_PATH,
		STREAK_SCENE_PATH,
	]
	var is_level_scene := scene_path.begins_with("res://niveles/nivel_")
	_hud_root.visible = not hidden_scenes.has(scene_path) and not is_level_scene


func _conectar_badge_racha() -> void:
	if _racha == null or not _racha.has_signal("pressed"):
		return
	var callback := Callable(self, "_on_racha_presionada")
	if not _racha.is_connected("pressed", callback):
		_racha.connect("pressed", callback)


# --- Profile overlay callbacks ---

func _on_boton_perfil_presionado() -> void:
	_profile_button.visible = false
	_profile_overlay.mostrar_superposicion()


func _on_racha_presionada() -> void:
	var current_scene_path := _obtener_ruta_escena_actual()
	if current_scene_path.is_empty() or current_scene_path == STREAK_SCENE_PATH:
		return
	if _profile_overlay != null:
		_profile_overlay.ocultar_superposicion()
	if _profile_button != null:
		_profile_button.visible = true
	@warning_ignore("static_called_on_instance")
	GameSceneRouter.ir_a_racha(get_tree(), current_scene_path)


func _on_superposicion_cierre_solicitado() -> void:
	_profile_button.visible = true
	_profile_overlay.ocultar_superposicion()


func _on_superposicion_reanudar_presionado() -> void:
	_profile_button.visible = true
	_profile_overlay.ocultar_superposicion()
	if not _save_manager_listo() or not SaveManager.puede_reanudar_guardado_actual():
		return
	var resume_state := SaveManager.recargar_desde_disco_y_obtener_reanudacion()
	@warning_ignore("static_called_on_instance")
	GameSceneRouter.ir_a_reanudar(get_tree(), resume_state, RESUME_FALLBACK_SCENE)


func _on_superposicion_editar_perfil_presionado() -> void:
	if _save_manager_listo():
		SaveManager.guardar_progreso_en_disco()
	var current_scene_path := _obtener_ruta_escena_actual()
	if current_scene_path.is_empty():
		current_scene_path = RESUME_FALLBACK_SCENE
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, current_scene_path)
	@warning_ignore("static_called_on_instance")
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_superposicion_guardar_presionado() -> void:
	pass


func _on_superposicion_reiniciar_presionado() -> void:
	var result: Dictionary = await SaveManager.reiniciar_todo_progreso()
	if not result.get("ok", false):
		_profile_overlay.mostrar_feedback_reset(
			str(result.get("message", "No se pudo reiniciar el progreso.")),
			false
		)
		return
	_profile_overlay.refrescar()
	_profile_overlay.mostrar_feedback_reset(str(result.get("message", "Progreso reiniciado.")), true)

func _on_superposicion_ranking_presionado() -> void:
	_profile_overlay.ocultar_superposicion()
	var leaderboard := preload("res://interface/leaderboard/LeaderboardScene.tscn").instantiate()
	add_child(leaderboard)
	
func _on_superposicion_logout_presionado() -> void:
	_ejecutar_logout()


func _ejecutar_logout() -> void:
	await AuthApi.cerrar_sesion()
	_profile_overlay.visible = false
	_profile_button.visible = true
	@warning_ignore("static_called_on_instance")
	GameSceneRouter.go_to_main_menu(get_tree())


func _obtener_ruta_escena_actual() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return ""
	return str(get_tree().current_scene.scene_file_path).strip_edges()


func _instalar_aviso_verificacion_mail() -> void:
	var nudge_scene := load(MAIL_NUDGE_SCENE_PATH) as PackedScene
	if nudge_scene == null:
		return
	_mail_verify_nudge = nudge_scene.instantiate() as CanvasLayer
	if _mail_verify_nudge == null:
		return
	add_child(_mail_verify_nudge)
	if _mail_verify_nudge.has_signal("ir_a_perfil_solicitado"):
		_mail_verify_nudge.ir_a_perfil_solicitado.connect(_on_aviso_verificacion_ir_perfil)
	_refrescar_aviso_verificacion_mail()


func _refrescar_aviso_verificacion_mail() -> void:
	if not is_instance_valid(_mail_verify_nudge) or not _mail_verify_nudge.has_method("refrescar"):
		return
	var scene_path := _obtener_ruta_escena_actual()
	var hidden := scene_path in [
		PROFILE_EDITOR_SCENE_PATH,
		SPLASH_SCENE_PATH,
		INTRO_SCENE_PATH,
	]
	if hidden:
		_mail_verify_nudge.visible = false
		return
	_mail_verify_nudge.refrescar()


func _on_aviso_verificacion_ir_perfil() -> void:
	var scene_path := _obtener_ruta_escena_actual()
	if not scene_path.is_empty():
		get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, scene_path)
	GameSceneRouter.go_to_profile_editor(get_tree())
