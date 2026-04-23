extends Control

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DayCircleScript := preload("res://interface/components/DayCircle.gd")
const DEFAULT_RETURN_SCENE := "res://mapas/MapScene.tscn"
const STREAK_RETURN_SCENE_META := "streak_return_scene"
const STREAK_FEEDBACK_META := "streak_feedback"
const STREAK_CONTINUE_TARGET_META := "streak_continue_target"
const STREAK_PREVIEW_COUNTS_KEY := "mock_streak_counts"

@export var empty_message := "Completa una actividad para iniciar la racha."
@export var feedback_default_message := "Hoy sostuviste la racha."
@export var week_messages: PackedStringArray = PackedStringArray()

var _current_count: int = 0
var _best_count: int = 0
var _status_key: String = "inactive"
var _status_detail: String = ""
var _feedback_continue_target: Dictionary = {}
var _mock_preview_counts: Array[int] = []
var _day_circles: Array[Control] = []
var _connector_sprites: Array[Sprite2D] = []

@onready var map_hud: CanvasLayer = $StreakView/MapHud
@onready var streak_count_label: Label = $StreakView/nroRacha
@onready var back_button: Button = $StreakView/MapHud/HudRoot/BackAnchor/BackButton
@onready var _detail_label: Label = $StreakView/EstadoRacha
@onready var _continue_button: Button = $StreakView/ContinueButton


func _ready() -> void:
	_cache_progress_nodes()
	_connect_continue_button()
	_connect_map_hud()
	_load_entry_state()


func render(streak_view_model: Dictionary = {}) -> void:
	_feedback_continue_target = {}
	_mock_preview_counts.clear()
	_set_feedback_mode(false)
	_apply_view_model(_resolve_view_model(streak_view_model))


func _load_entry_state() -> void:
	var feedback: Dictionary = _consume_root_meta_dictionary(STREAK_FEEDBACK_META)
	_feedback_continue_target = _consume_root_meta_dictionary(STREAK_CONTINUE_TARGET_META)
	_mock_preview_counts = _extract_mock_preview_counts(_feedback_continue_target)
	if feedback.is_empty():
		render()
		return
	_show_feedback(feedback)


func _show_feedback(feedback: Dictionary) -> void:
	_apply_view_model(_resolve_view_model({}))
	_current_count = max(1, int(feedback.get("current_count", _current_count)))
	_best_count = max(_current_count, int(feedback.get("best_count", _best_count)))
	if _status_key == "inactive":
		_status_key = "active_today"
	_status_detail = _build_feedback_message(feedback)
	_set_feedback_mode(true)
	_refresh_ui()


func _resolve_view_model(streak_view_model: Dictionary) -> Dictionary:
	if not streak_view_model.is_empty():
		return streak_view_model
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node != null and global_node.has_method("get_streak_view_model"):
		var resolved: Variant = global_node.call("get_streak_view_model")
		if resolved is Dictionary:
			return resolved
	return {}


func _apply_view_model(streak_view_model: Dictionary) -> void:
	_current_count = max(0, int(streak_view_model.get("current_count", 0)))
	_best_count = max(_current_count, int(streak_view_model.get("best_count", 0)))
	_status_key = str(streak_view_model.get("status_key", "inactive")).strip_edges()
	_status_detail = str(streak_view_model.get("status_detail", "")).strip_edges()
	_refresh_ui()


func _refresh_ui() -> void:
	if not is_node_ready():
		return
	streak_count_label.text = str(_current_count)
	_update_status_text()
	_update_connector_visuals()
	_update_day_circles()


func _cache_progress_nodes() -> void:
	_day_circles = [
		$StreakView/HBoxContainer/DayCircle/TextureRect,
		$StreakView/HBoxContainer/DayCircle2/TextureRect,
		$StreakView/HBoxContainer/DayCircle3/TextureRect,
		$StreakView/HBoxContainer/DayCircle4/TextureRect,
		$StreakView/HBoxContainer/DayCircle5/TextureRect,
		$StreakView/HBoxContainer/DayCircle6/TextureRect,
		$StreakView/HBoxContainer/DayCircle7/TextureRect,
	]
	_connector_sprites = [
		$StreakView/HBoxContainer/lunYMar,
		$StreakView/HBoxContainer/lunAMier,
		$StreakView/HBoxContainer/lunAJue,
		$StreakView/HBoxContainer/lunAVie,
		$StreakView/HBoxContainer/lunASab,
		$StreakView/HBoxContainer/lunADom,
	]


func _connect_continue_button() -> void:
	if not _continue_button.pressed.is_connected(_on_continue_button_pressed):
		_continue_button.pressed.connect(_on_continue_button_pressed)


func _connect_map_hud() -> void:
	if map_hud == null or not map_hud.has_signal("back_requested"):
		return
	var callback := Callable(self, "_on_back_requested")
	if not map_hud.is_connected("back_requested", callback):
		map_hud.connect("back_requested", callback)


func _set_feedback_mode(enabled: bool) -> void:
	_continue_button.visible = enabled
	_continue_button.disabled = not enabled
	if back_button != null:
		back_button.visible = not enabled


func _update_status_text() -> void:
	if not _status_detail.is_empty():
		_detail_label.text = _status_detail
		return
	if _best_count > 0:
		_detail_label.text = "Mejor racha: %d dias" % _best_count
		return
	_detail_label.text = empty_message


func _update_connector_visuals() -> void:
	var visible_day_count: int = _get_visible_day_count()
	for connector_index in range(_connector_sprites.size()):
		var connector_sprite: Sprite2D = _connector_sprites[connector_index]
		if connector_sprite == null:
			continue
		connector_sprite.visible = (
			visible_day_count >= 2
			and connector_index == visible_day_count - 2
		)


func _update_day_circles() -> void:
	var visible_day_count: int = _get_visible_day_count()
	for day_index in range(_day_circles.size()):
		var circle_control: Control = _day_circles[day_index]
		if circle_control == null:
			continue
		var slot := circle_control.get_parent() as Control
		if slot != null:
			slot.visible = true
		var is_visible: bool = day_index < visible_day_count
		circle_control.visible = is_visible
		if not is_visible:
			continue
		circle_control.call("set_estado", DayCircleScript.Estado.COMPLETO)


func _get_visible_day_count() -> int:
	var cycle_days: int = _get_cycle_days()
	if _current_count <= 0:
		return 0
	if cycle_days <= 0:
		return 0
	var visible_day_count: int = _current_count % cycle_days
	if visible_day_count == 0:
		return cycle_days
	return visible_day_count


func _build_feedback_message(feedback: Dictionary) -> String:
	var count: int = max(1, int(feedback.get("current_count", _current_count)))
	var message: String = _resolve_streak_message(count)
	if not message.is_empty():
		return message
	return str(feedback.get("message", feedback_default_message)).strip_edges()


func _resolve_streak_message(count: int) -> String:
	var cycle_days: int = _get_cycle_days()
	if count <= 0:
		return ""
	if cycle_days <= 0:
		return ""
	var day_in_week: int = ((count - 1) % cycle_days) + 1
	var week_number: int = int((count - 1) / float(cycle_days)) + 1
	var message_index: int = day_in_week - 1
	if message_index < 0 or message_index >= week_messages.size():
		return ""
	var base_message: String = week_messages[message_index]
	if week_number == 1:
		return base_message
	return "Semana %d, dia %d. %s" % [week_number, day_in_week, base_message]


func _get_cycle_days() -> int:
	if not _day_circles.is_empty():
		return _day_circles.size()
	return week_messages.size()


func _consume_root_meta_dictionary(meta_key: String) -> Dictionary:
	if get_tree() == null or get_tree().root == null:
		return {}
	var tree_root: Window = get_tree().root
	if not tree_root.has_meta(meta_key):
		return {}
	var raw_meta: Variant = tree_root.get_meta(meta_key, {})
	tree_root.remove_meta(meta_key)
	if raw_meta is Dictionary:
		return (raw_meta as Dictionary).duplicate(true)
	return {}


func _extract_mock_preview_counts(continue_target: Dictionary) -> Array[int]:
	var preview_counts: Array[int] = []
	var cycle_days: int = _get_cycle_days()
	if continue_target.is_empty():
		return preview_counts
	var raw_counts: Variant = continue_target.get(STREAK_PREVIEW_COUNTS_KEY, [])
	continue_target.erase(STREAK_PREVIEW_COUNTS_KEY)
	if not (raw_counts is Array):
		return preview_counts
	for raw_value in raw_counts:
		var preview_count: int = int(raw_value)
		if preview_count < 1 or preview_count > cycle_days:
			continue
		if preview_counts.has(preview_count):
			continue
		preview_counts.append(preview_count)
	return preview_counts


func _show_next_mock_preview() -> bool:
	if _mock_preview_counts.is_empty():
		return false
	var preview_count: int = _mock_preview_counts[0]
	_mock_preview_counts.remove_at(0)
	_current_count = preview_count
	_best_count = max(_best_count, preview_count)
	_status_key = "active_today"
	_status_detail = _resolve_streak_message(preview_count)
	_refresh_ui()
	return true


func _on_continue_button_pressed() -> void:
	if _show_next_mock_preview():
		return
	if _feedback_continue_target.is_empty():
		_on_back_requested()
		return
	_go_to_continue_target(_feedback_continue_target)


func _go_to_continue_target(continue_target: Dictionary) -> void:
	match str(continue_target.get("type", "")).strip_edges():
		"map":
			GameSceneRouter.go_to_map(get_tree())
		"track_level":
			GameSceneRouter.go_to_track_level(
				get_tree(),
				str(continue_target.get("track_key", "")).strip_edges(),
				int(continue_target.get("level_number", -1))
			)
		"track_book":
			GameSceneRouter.go_to_track_book(
				get_tree(),
				str(continue_target.get("track_key", "")).strip_edges()
			)
		_:
			_on_back_requested()


func _on_back_requested() -> void:
	if get_tree() == null:
		return
	get_tree().change_scene_to_file(_resolve_return_scene_path())


func _resolve_return_scene_path() -> String:
	if get_tree() == null or get_tree().root == null:
		return DEFAULT_RETURN_SCENE
	var tree_root: Window = get_tree().root
	if not tree_root.has_meta(STREAK_RETURN_SCENE_META):
		return DEFAULT_RETURN_SCENE
	var return_scene_path: String = str(
		tree_root.get_meta(STREAK_RETURN_SCENE_META, "")
	).strip_edges()
	tree_root.remove_meta(STREAK_RETURN_SCENE_META)
	if return_scene_path.is_empty():
		return DEFAULT_RETURN_SCENE
	return return_scene_path
