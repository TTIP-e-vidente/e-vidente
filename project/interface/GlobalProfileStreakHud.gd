extends CanvasLayer

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const STREAK_SEAL_SCENE := preload("res://interface/components/StreakDailySeal.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")

const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ARCHIVERO_SCENE_PATH := "res://interface/archivero.tscn"
const MAP_SCENE_PATH := "res://mapas/MapScene.tscn"
const PROFILE_EDITOR_SCENE_PATH := "res://interface/auth.tscn"
const SPLASH_SCENE_PATH := "res://interface/evidente.tscn"
const INTRO_SCENE_PATH := "res://niveles/intro.tscn"

var _hud_root: Control
var _streak_seal: Control
var _profile_button: Button
var _last_scene_path := ""


func _ready() -> void:
	layer = 75
	_build_hud()
	_connect_save_manager_signals()
	get_tree().node_added.connect(_on_tree_node_added)
	_refresh_hud()


func _exit_tree() -> void:
	_disconnect_save_manager_signals()
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)


func _build_hud() -> void:
	_hud_root = Control.new()
	_hud_root.name = "GlobalProfileStreakHudRoot"
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	_streak_seal = STREAK_SEAL_SCENE.instantiate() as Control
	if _streak_seal != null:
		_streak_seal.name = "GlobalStreakDailySeal"
		_streak_seal.anchor_left = 1.0
		_streak_seal.anchor_top = 0.0
		_streak_seal.anchor_right = 1.0
		_streak_seal.anchor_bottom = 0.0
		_streak_seal.offset_left = -152.0
		_streak_seal.offset_top = 16.0
		_streak_seal.offset_right = -16.0
		_streak_seal.offset_bottom = 152.0
		_hud_root.add_child(_streak_seal)

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
	_profile_button.tooltip_text = "Abrir perfil"
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
	# Refresh when scene roots change so the HUD visibility follows each screen.
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
	if _streak_seal != null and _streak_seal.has_method("render"):
		_streak_seal.call("render")


func _apply_scene_visibility(scene_path: String) -> void:
	var hidden_scenes := [
		ARCHIVERO_SCENE_PATH,
		MAP_SCENE_PATH,
		PROFILE_EDITOR_SCENE_PATH,
		SPLASH_SCENE_PATH,
		INTRO_SCENE_PATH,
	]
	# Also hide on any Level gameplay scene
	var is_level_scene := scene_path.begins_with("res://niveles/nivel_")
	_hud_root.visible = not hidden_scenes.has(scene_path) and not is_level_scene


func _on_profile_button_pressed() -> void:
	var current_scene_path := _get_current_scene_path()
	if current_scene_path.is_empty() or current_scene_path == PROFILE_EDITOR_SCENE_PATH:
		return
	SaveManager.save_progress_to_disk()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, current_scene_path)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _get_current_scene_path() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return ""
	return str(get_tree().current_scene.scene_file_path).strip_edges()
