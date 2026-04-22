extends CanvasLayer

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const RACHA_SCENE := preload("res://interface/components/Racha.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")
const PROFILE_OVERLAY_SCENE := preload("res://interface/components/ProfileOverlayPanel.tscn")

const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ARCHIVERO_SCENE_PATH := "res://interface/archivero.tscn"
const PROFILE_EDITOR_SCENE_PATH := "res://interface/auth.tscn"
const SPLASH_SCENE_PATH := "res://interface/evidente.tscn"
const INTRO_SCENE_PATH := "res://niveles/intro.tscn"
const SELECTOR_SCENE_PATH := "res://niveles/selector.tscn"
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
	_build_hud()
	_profile_overlay = PROFILE_OVERLAY_SCENE.instantiate()
	add_child(_profile_overlay)
	_profile_overlay.resume_pressed.connect(_on_overlay_resume_pressed)
	_profile_overlay.save_pressed.connect(_on_overlay_guardar_pressed)
	_profile_overlay.edit_profile_pressed.connect(_on_overlay_edit_profile_pressed)
	_profile_overlay.reset_progress_pressed.connect(_on_overlay_reset_pressed)
	_profile_overlay.close_requested.connect(_on_overlay_close_requested)
	_connect_save_manager_signals()
	get_tree().node_added.connect(_on_tree_node_added)
	_refresh_hud()


func _exit_tree() -> void:
	_disconnect_save_manager_signals()
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)


func _build_hud() -> void:
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
	_profile_button.tooltip_text = "Mi progreso"
	_profile_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_profile_button.pressed.connect(_on_profile_button_pressed)
	_hud_root.add_child(_profile_button)


func _connect_save_manager_signals() -> void:
	if SaveManager == null:
		return
	if not SaveManager.save_status_changed.is_connected(_on_save_manager_changed):
		SaveManager.save_status_changed.connect(_on_save_manager_changed)
	if not SaveManager.progress_loaded.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_loaded.connect(_on_save_manager_profile_changed)
	if not SaveManager.progress_saved.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_saved.connect(_on_save_manager_profile_changed)
	if not SaveManager.user_registered.is_connected(_on_save_manager_profile_changed):
		SaveManager.user_registered.connect(_on_save_manager_profile_changed)


func _disconnect_save_manager_signals() -> void:
	if SaveManager == null:
		return
	if SaveManager.save_status_changed.is_connected(_on_save_manager_changed):
		SaveManager.save_status_changed.disconnect(_on_save_manager_changed)
	if SaveManager.progress_loaded.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_loaded.disconnect(_on_save_manager_profile_changed)
	if SaveManager.progress_saved.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_saved.disconnect(_on_save_manager_profile_changed)
	if SaveManager.user_registered.is_connected(_on_save_manager_profile_changed):
		SaveManager.user_registered.disconnect(_on_save_manager_profile_changed)


func _on_tree_node_added(_node: Node) -> void:
	call_deferred("_refresh_hud")


func _on_save_manager_changed(_status: Dictionary) -> void:
	_refresh_hud()


func _on_save_manager_profile_changed(_profile: Dictionary) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	var scene_path := _get_current_scene_path()
	if scene_path != _last_scene_path:
		_last_scene_path = scene_path
		_apply_scene_visibility(scene_path)
		if _profile_overlay != null and _profile_overlay.visible:
			_profile_overlay.visible = false
			_profile_button.visible = true
	if _racha != null and _racha.has_method("render"):
		_racha.call("render")
	if _profile_button != null and _profile_button.has_method("refresh_profile_icon"):
		_profile_button.call("refresh_profile_icon")


func _apply_scene_visibility(scene_path: String) -> void:
	var hidden_scenes := [
		ARCHIVERO_SCENE_PATH,
		PROFILE_EDITOR_SCENE_PATH,
		SPLASH_SCENE_PATH,
		INTRO_SCENE_PATH,
		SELECTOR_SCENE_PATH,
	]
	var is_level_scene := scene_path.begins_with("res://niveles/nivel_")
	_hud_root.visible = not hidden_scenes.has(scene_path) and not is_level_scene


# --- Profile overlay callbacks ---

func _on_profile_button_pressed() -> void:
	_profile_button.visible = false
	_profile_overlay.show_overlay()


func _on_overlay_close_requested() -> void:
	_profile_button.visible = true
	_profile_overlay.hide_overlay()


func _on_overlay_resume_pressed() -> void:
	_profile_button.visible = true
	_profile_overlay.hide_overlay()
	if not SaveManager.can_resume_current_save():
		return
	var resume_state := SaveManager.reload_from_disk_and_get_resume()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, RESUME_FALLBACK_SCENE)


func _on_overlay_edit_profile_pressed() -> void:
	SaveManager.save_progress_to_disk()
	var current_scene_path := _get_current_scene_path()
	if current_scene_path.is_empty():
		current_scene_path = RESUME_FALLBACK_SCENE
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, current_scene_path)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_overlay_guardar_pressed() -> void:
	SaveManager.save_progress_to_disk()
	_profile_overlay.refresh()


func _on_overlay_reset_pressed() -> void:
	SaveManager.reset_all_progress()
	_profile_overlay.visible = false
	_profile_button.visible = true
	GameSceneRouter.go_to_mode_selector(get_tree())


func _get_current_scene_path() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return ""
	return str(get_tree().current_scene.scene_file_path).strip_edges()
