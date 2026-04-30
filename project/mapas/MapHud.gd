extends CanvasLayer

signal back_requested

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MAP_SCENE_PATH := "res://mapas/MapScene.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"

@onready var racha: Control = $HudRoot/TopLeftAnchor/Racha
@onready var profile_button: Button = $HudRoot/TopRightAnchor/ProfileButton
@onready var profile_overlay: ProfileOverlayPanel = $ProfileOverlayPanel


func _ready() -> void:
	_ocultar_superposicion_perfil()
	_conectar_insignia_racha()
	_conectar_senales_guardado()
	_actualizar_hud()


func _exit_tree() -> void:
	_desconectar_senales_guardado()


func _conectar_senales_guardado() -> void:
	if SaveManager == null:
		return
	if not SaveManager.save_status_changed.is_connected(_al_cambiar_estado_guardado):
		SaveManager.save_status_changed.connect(_al_cambiar_estado_guardado)
	if not SaveManager.progress_loaded.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.progress_loaded.connect(_al_cambiar_perfil_guardado)
	if not SaveManager.progress_saved.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.progress_saved.connect(_al_cambiar_perfil_guardado)
	if not SaveManager.user_registered.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.user_registered.connect(_al_cambiar_perfil_guardado)


func _desconectar_senales_guardado() -> void:
	if SaveManager == null:
		return
	if SaveManager.save_status_changed.is_connected(_al_cambiar_estado_guardado):
		SaveManager.save_status_changed.disconnect(_al_cambiar_estado_guardado)
	if SaveManager.progress_loaded.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.progress_loaded.disconnect(_al_cambiar_perfil_guardado)
	if SaveManager.progress_saved.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.progress_saved.disconnect(_al_cambiar_perfil_guardado)
	if SaveManager.user_registered.is_connected(_al_cambiar_perfil_guardado):
		SaveManager.user_registered.disconnect(_al_cambiar_perfil_guardado)


func _actualizar_hud() -> void:
	if racha != null and racha.has_method("render"):
		racha.call("render")
	if profile_button != null and profile_button.has_method("refresh_profile_icon"):
		profile_button.call("refresh_profile_icon")
	if profile_overlay != null and profile_overlay.visible:
		profile_overlay.refrescar()


func _conectar_insignia_racha() -> void:
	if racha == null or not racha.has_signal("pressed"):
		return
	var callback := Callable(self, "_on_racha_presionado")
	if not racha.is_connected("pressed", callback):
		racha.connect("pressed", callback)


func _on_profile_button_pressed() -> void:
	_mostrar_superposicion_perfil()


func _on_racha_presionado() -> void:
	var ruta_escena_actual: String = _obtener_ruta_escena_retorno()
	if ruta_escena_actual == GameSceneRouter.STREAK_SCENE_PATH:
		return
	_ocultar_superposicion_perfil()
	GameSceneRouter.go_to_streak(get_tree(), ruta_escena_actual)


func _on_back_button_pressed() -> void:
	back_requested.emit()


func _on_superposicion_cerrar_solicitado() -> void:
	_ocultar_superposicion_perfil()


func _on_superposicion_reanudar_presionado() -> void:
	_ocultar_superposicion_perfil()
	if not SaveManager.puede_reanudar_guardado_actual():
		return
	var estado_reanudacion: Dictionary = SaveManager.recargar_desde_disco_y_obtener_reanudacion()
	GameSceneRouter.go_to_resume(get_tree(), estado_reanudacion, _obtener_ruta_escena_retorno())


func _on_superposicion_edit_perfil_presionado() -> void:
	SaveManager.guardar_progreso_en_disco()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, _obtener_ruta_escena_retorno())
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_overlay_save_pressed() -> void:
	SaveManager.guardar_progreso_en_disco()
	_actualizar_hud()


func _on_superposicion_reiniciar_presionado() -> void:
	SaveManager.reiniciar_todo_progreso()
	_ocultar_superposicion_perfil()
	GameSceneRouter.go_to_mode_selector(get_tree())


func _al_cambiar_estado_guardado(_status: Dictionary) -> void:
	_actualizar_hud()


func _al_cambiar_perfil_guardado(_profile: Dictionary) -> void:
	_actualizar_hud()


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
