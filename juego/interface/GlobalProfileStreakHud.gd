# HELPER_INTERNO
# HUD global (CanvasLayer 75) con botón de perfil y badge de racha.
extends CanvasLayer

const RACHA_SCENE := preload("res://interface/components/Racha.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")
const PROFILE_OVERLAY_SCENE := preload("res://interface/components/ProfileOverlayPanel.tscn")

const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ARCHIVERO_SCENE_PATH := "res://interface/archivero.tscn"
const PROFILE_EDITOR_SCENE_PATH := "res://interface/auth.tscn"
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
	_profile_overlay.close_requested.connect(_on_superposicion_cierre_solicitado)
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
	if SaveManager == null:
		return
	if not SaveManager.save_status_changed.is_connected(_on_save_manager_cambiado):
		SaveManager.save_status_changed.connect(_on_save_manager_cambiado)
	if not SaveManager.progress_loaded.is_connected(_on_save_manager_perfil_cambiado):
		SaveManager.progress_loaded.connect(_on_save_manager_perfil_cambiado)
	if not SaveManager.progress_saved.is_connected(_on_save_manager_perfil_cambiado):
		SaveManager.progress_saved.connect(_on_save_manager_perfil_cambiado)
	if not SaveManager.user_registered.is_connected(_on_save_manager_perfil_cambiado):
		SaveManager.user_registered.connect(_on_save_manager_perfil_cambiado)


func _desconectar_senales_save_manager() -> void:
	if SaveManager == null:
		return
	if SaveManager.save_status_changed.is_connected(_on_save_manager_cambiado):
		SaveManager.save_status_changed.disconnect(_on_save_manager_cambiado)
	if SaveManager.progress_loaded.is_connected(_on_save_manager_perfil_cambiado):
		SaveManager.progress_loaded.disconnect(_on_save_manager_perfil_cambiado)
	if SaveManager.progress_saved.is_connected(_on_save_manager_perfil_cambiado):
		SaveManager.progress_saved.disconnect(_on_save_manager_perfil_cambiado)
	if SaveManager.user_registered.is_connected(_on_save_manager_perfil_cambiado):
		SaveManager.user_registered.disconnect(_on_save_manager_perfil_cambiado)


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


func _aplicar_visibilidad_escena(scene_path: String) -> void:
	var hidden_scenes := [
		ARCHIVERO_SCENE_PATH,
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
	GameSceneRouter.ir_a_racha(get_tree(), current_scene_path)


func _on_superposicion_cierre_solicitado() -> void:
	_profile_button.visible = true
	_profile_overlay.ocultar_superposicion()


func _on_superposicion_reanudar_presionado() -> void:
	_profile_button.visible = true
	_profile_overlay.ocultar_superposicion()
	if not SaveManager.puede_reanudar_guardado_actual():
		return
	var resume_state := SaveManager.recargar_desde_disco_y_obtener_reanudacion()
	GameSceneRouter.ir_a_reanudar(get_tree(), resume_state, RESUME_FALLBACK_SCENE)


func _on_superposicion_editar_perfil_presionado() -> void:
	SaveManager.guardar_progreso_en_disco()
	var current_scene_path := _obtener_ruta_escena_actual()
	if current_scene_path.is_empty():
		current_scene_path = RESUME_FALLBACK_SCENE
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, current_scene_path)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_superposicion_guardar_presionado() -> void:
	SaveManager.guardar_progreso_en_disco()
	_profile_overlay.refrescar()


func _on_superposicion_reiniciar_presionado() -> void:
	SaveManager.reiniciar_todo_progreso()
	_profile_overlay.visible = false
	_profile_button.visible = true
	GameSceneRouter.go_to_mode_selector(get_tree())


func _on_superposicion_logout_presionado() -> void:
	AuthApi.cerrar_sesion()
	_profile_overlay.visible = false
	_profile_button.visible = true
	GameSceneRouter.go_to_main_menu(get_tree())


func _obtener_ruta_escena_actual() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return ""
	return str(get_tree().current_scene.scene_file_path).strip_edges()
