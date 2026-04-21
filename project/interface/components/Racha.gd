@tool
class_name Racha
extends Control

const SPRAY_TEXTURE := preload("res://assets-sistema/racha-diaria/racha-diaria.png")
const COUNT_FONT := preload("res://fonts/RubikSprayPaint-Regular.ttf")

var _current_count: int = 0

@onready var background: TextureRect = $Background
@onready var count_label: Label = $CountLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_scene_nodes()
	render()


func render(streak_view_model: Dictionary = {}) -> void:
	_apply_view_model(_resolve_view_model(streak_view_model))


func set_badge(number_value: int, _next_status_key: String = "") -> void:
	_current_count = max(0, number_value)
	_refresh_ui()


func _resolve_view_model(streak_view_model: Dictionary) -> Dictionary:
	if not streak_view_model.is_empty():
		return streak_view_model
	var global_node := get_node_or_null("/root/Global")
	if global_node and global_node.has_method("get_streak_view_model"):
		return global_node.get_streak_view_model()
	return {}


func _apply_view_model(streak_view_model: Dictionary) -> void:
	_current_count = max(0, int(streak_view_model.get("current_count", 0)))
	_refresh_ui()


func _configure_scene_nodes() -> void:
	if background != null:
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.offset_left = 0.0
		background.offset_top = 0.0
		background.offset_right = 0.0
		background.offset_bottom = 0.0
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.texture = SPRAY_TEXTURE
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if count_label != null:
		count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		count_label.offset_left = 0.0
		count_label.offset_top = 0.0
		count_label.offset_right = 0.0
		count_label.offset_bottom = 0.0
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.add_theme_font_override("font", COUNT_FONT)
		count_label.add_theme_color_override("font_color", Color(0, 0, 0, 1.0))

	_refresh_ui()


func _refresh_ui() -> void:
	if not is_node_ready():
		return

	if count_label != null:
		var count_text: String = str(_current_count)
		count_label.text = count_text
		count_label.add_theme_font_size_override(
			"font_size",
			_resolve_count_font_size(count_text)
		)


func _resolve_count_font_size(count_text: String) -> int:
	if count_text.length() >= 3:
		return 34
	if count_text.length() == 2:
		return 42
	return 52