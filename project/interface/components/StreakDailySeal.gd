@tool
class_name StreakDailySeal
extends Control

const ARC_FONT := preload("res://fonts/Rubik-Italic-VariableFont_wght.ttf")
const COUNT_FONT := preload("res://fonts/RubikSprayPaint-Regular.ttf")

const STATUS_INACTIVE := "inactive"
const STATUS_PENDING_TODAY := "pending_today"
const STATUS_ACTIVE_TODAY := "active_today"

const DEFAULT_TITLE_TEXT := "racha diaria"
const SPOKE_COUNT := 40
const ARC_FONT_SIZE := 16
const ARC_START_ANGLE := -160.0 * PI / 180.0
const ARC_END_ANGLE := -18.0 * PI / 180.0

var _current_count := 0
var _status_key := STATUS_INACTIVE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func render(streak_view_model: Dictionary = {}) -> void:
	_apply_view_model(_resolve_view_model(streak_view_model))


func set_badge(number_value: int, next_status_key: String = STATUS_INACTIVE) -> void:
	_current_count = max(0, number_value)
	_status_key = _normalize_status_key(next_status_key)
	queue_redraw()


func _resolve_view_model(streak_view_model: Dictionary) -> Dictionary:
	if not streak_view_model.is_empty():
		return streak_view_model
	var global_node := get_node_or_null("/root/Global")
	if global_node and global_node.has_method("get_streak_view_model"):
		return global_node.get_streak_view_model()
	return {}


func _apply_view_model(streak_view_model: Dictionary) -> void:
	_current_count = max(0, int(streak_view_model.get("current_count", 0)))
	_status_key = _normalize_status_key(
		str(streak_view_model.get("status_key", STATUS_INACTIVE))
	)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var shortest_side: float = minf(size.x, size.y)
	var disc_radius: float = shortest_side * 0.24
	var spoke_inner_radius: float = disc_radius + 10.0
	var spoke_outer_radius: float = shortest_side * 0.44
	var title_radius: float = shortest_side * 0.46

	_draw_spokes(center, spoke_inner_radius, spoke_outer_radius)
	draw_circle(center, disc_radius, Color(0.1, 0.1, 0.1, 1.0))
	_draw_count(center)
	_draw_arc_title(center, title_radius)


func _draw_spokes(center: Vector2, inner_radius: float, outer_radius: float) -> void:
	var spoke_color: Color = _resolve_spoke_color()
	for index in range(SPOKE_COUNT):
		var angle: float = (TAU * float(index)) / float(SPOKE_COUNT)
		var from: Vector2 = center + Vector2.RIGHT.rotated(angle) * inner_radius
		var to: Vector2 = center + Vector2.RIGHT.rotated(angle) * outer_radius
		draw_line(from, to, spoke_color, 1.1, true)


func _draw_count(center: Vector2) -> void:
	var count_text: String = str(_current_count)
	var font_size: int = _resolve_count_font_size(count_text)
	var text_size: Vector2 = COUNT_FONT.get_string_size(
		count_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	)
	var baseline: Vector2 = center + Vector2(
		-text_size.x * 0.5,
		-text_size.y * 0.5 + COUNT_FONT.get_ascent(font_size)
	)
	draw_string(
		COUNT_FONT,
		baseline,
		count_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(0.97, 0.97, 0.97, 1.0)
	)


func _draw_arc_title(center: Vector2, title_radius: float) -> void:
	var total_units: float = 0.0
	for index in range(DEFAULT_TITLE_TEXT.length()):
		total_units += _get_title_unit(DEFAULT_TITLE_TEXT.substr(index, 1))

	var advanced_units: float = 0.0
	for index in range(DEFAULT_TITLE_TEXT.length()):
		var character: String = DEFAULT_TITLE_TEXT.substr(index, 1)
		var unit: float = _get_title_unit(character)
		var progress: float = (advanced_units + unit * 0.5) / total_units
		advanced_units += unit
		if character == " ":
			continue

		var angle: float = lerpf(ARC_START_ANGLE, ARC_END_ANGLE, progress)
		var glyph_center: Vector2 = center + Vector2.RIGHT.rotated(angle) * title_radius
		var glyph_size: Vector2 = ARC_FONT.get_string_size(
			character,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			ARC_FONT_SIZE
		)
		draw_set_transform(glyph_center, angle + PI * 0.5, Vector2.ONE)
		draw_string(
			ARC_FONT,
			Vector2(
				-glyph_size.x * 0.5,
				-glyph_size.y * 0.5 + ARC_FONT.get_ascent(ARC_FONT_SIZE)
			),
			character,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			ARC_FONT_SIZE,
			_resolve_title_color()
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _resolve_count_font_size(count_text: String) -> int:
	if count_text.length() >= 3:
		return 34
	if count_text.length() == 2:
		return 42
	return 52


func _get_title_unit(character: String) -> float:
	return 0.55 if character == " " else 1.0


func _resolve_spoke_color() -> Color:
	match _status_key:
		STATUS_ACTIVE_TODAY:
			return Color(0.15, 0.15, 0.15, 0.18)
		STATUS_PENDING_TODAY:
			return Color(0.15, 0.15, 0.15, 0.14)
		_:
			return Color(0.15, 0.15, 0.15, 0.1)


func _resolve_title_color() -> Color:
	return Color(0.18, 0.17, 0.14, 0.92)


func _normalize_status_key(value: String) -> String:
	match value.strip_edges():
		STATUS_ACTIVE_TODAY:
			return STATUS_ACTIVE_TODAY
		STATUS_PENDING_TODAY:
			return STATUS_PENDING_TODAY
		_:
			return STATUS_INACTIVE