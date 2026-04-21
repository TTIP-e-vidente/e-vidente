extends CanvasLayer

signal back_requested

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MAP_SCENE_PATH := "res://mapas/MapScene.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"

@onready var streak_seal: Control = $HudRoot/TopLeftAnchor/StreakDailySeal
@onready var profile_button: Button = $HudRoot/TopRightAnchor/ProfileButton
@onready var profile_overlay: ProfileOverlayPanel = $ProfileOverlayPanel


func _ready() -> void:
	_hide_profile_overlay()
	_connect_save_manager_signals()
	_refresh_hud()


func _exit_tree() -> void:
	_disconnect_save_manager_signals()


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


func _refresh_hud() -> void:
	if streak_seal != null and streak_seal.has_method("render"):
		streak_seal.call("render")
	if profile_overlay != null and profile_overlay.visible:
		profile_overlay.refresh()


func _on_profile_button_pressed() -> void:
	_show_profile_overlay()


func _on_back_button_pressed() -> void:
	back_requested.emit()


func _on_overlay_close_requested() -> void:
	_hide_profile_overlay()


func _on_overlay_resume_pressed() -> void:
	_hide_profile_overlay()
	if not SaveManager.can_resume_current_save():
		return
	var resume_state: Dictionary = SaveManager.reload_from_disk_and_get_resume()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, _get_scene_to_return_to())


func _on_overlay_edit_profile_pressed() -> void:
	SaveManager.save_progress_to_disk()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, _get_scene_to_return_to())
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_overlay_save_pressed() -> void:
	SaveManager.save_progress_to_disk()
	_refresh_hud()


func _on_overlay_reset_pressed() -> void:
	SaveManager.reset_all_progress()
	_hide_profile_overlay()
	GameSceneRouter.go_to_mode_selector(get_tree())


func _on_save_manager_changed(_status: Dictionary) -> void:
	_refresh_hud()


func _on_save_manager_profile_changed(_profile: Dictionary) -> void:
	_refresh_hud()


func _show_profile_overlay() -> void:
	profile_button.visible = false
	profile_overlay.show_overlay()


func _hide_profile_overlay() -> void:
	profile_button.visible = true
	profile_overlay.hide_overlay()


func _get_scene_to_return_to() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return MAP_SCENE_PATH
	var scene_path: String = str(get_tree().current_scene.scene_file_path).strip_edges()
	return scene_path if not scene_path.is_empty() else MAP_SCENE_PATH
