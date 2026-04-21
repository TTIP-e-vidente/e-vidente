@tool
extends Button

const LABEL_FONT := preload("res://fonts/Rubik-VariableFont_wght.ttf")

const DEFAULT_LABEL_TEXT := "Mi progreso"
const BUTTON_MIN_SIZE := Vector2(220.0, 68.0)
const ARC_FONT_SIZE := 11
const ARC_START_ANGLE := -158.0 * PI / 180.0
const ARC_END_ANGLE := -22.0 * PI / 180.0
const TILE_CORNER_RADIUS := 14
const TILE_BG_COLOR := Color(0.9, 0.9, 0.9, 0.92)
const TILE_HOVER_COLOR := Color(0.93, 0.93, 0.93, 0.98)
const TILE_SHADOW_COLOR := Color(0.15, 0.14, 0.11, 0.14)
const FACE_FILL_COLOR := Color(0.98, 0.98, 0.98, 1.0)
const FACE_LINE_COLOR := Color(0.17, 0.17, 0.17, 0.96)
const FACE_BLUSH_COLOR := Color(0.95, 0.77, 0.78, 0.4)
const TITLE_COLOR := Color(0.18, 0.164, 0.121, 1.0)

var _label_text: String = DEFAULT_LABEL_TEXT
var _status_icon: Texture2D = null
var _is_hovered: bool = false


func _ready() -> void:
	flat = true
	text = ""
	icon = null
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_empty_style_overrides()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return BUTTON_MIN_SIZE


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_is_hovered = true
		queue_redraw()
		return
	if what == NOTIFICATION_MOUSE_EXIT:
		_is_hovered = false
		queue_redraw()
		return
	if (
		what == NOTIFICATION_RESIZED
		or what == NOTIFICATION_THEME_CHANGED
		or what == NOTIFICATION_FOCUS_ENTER
		or what == NOTIFICATION_FOCUS_EXIT
	):
		queue_redraw()


func set_label_text(next_label_text: String) -> void:
	var resolved_label_text: String = next_label_text.strip_edges()
	_label_text = (
		DEFAULT_LABEL_TEXT
		if resolved_label_text.is_empty()
		else resolved_label_text
	)
	queue_redraw()


func set_status_icon(next_status_icon: Texture2D) -> void:
	_status_icon = next_status_icon
	queue_redraw()


func _draw() -> void:
	var tile_size: float = minf(size.y - 6.0, 62.0)
	var tile_position: Vector2 = Vector2(
		size.x * 0.7 - tile_size * 0.5,
		(size.y - tile_size) * 0.5
	)
	var tile_rect: Rect2 = Rect2(tile_position, Vector2(tile_size, tile_size))
	var seal_center: Vector2 = tile_rect.position + tile_rect.size * Vector2(0.5, 0.55)

	_draw_tile(tile_rect)
	_draw_arc_label(seal_center, tile_rect.size.x * 0.47)
	_draw_face(tile_rect)


func _apply_empty_style_overrides() -> void:
	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("focus", empty_style)
	add_theme_stylebox_override("disabled", empty_style)


func _draw_tile(tile_rect: Rect2) -> void:
	var shadow_rect: Rect2 = Rect2(
		tile_rect.position + Vector2(0.0, 4.0),
		tile_rect.size
	)
	var shadow_box: StyleBoxFlat = _build_round_box(TILE_SHADOW_COLOR, TILE_CORNER_RADIUS)
	var tile_color: Color = TILE_HOVER_COLOR if _is_hovered else TILE_BG_COLOR
	var tile_box: StyleBoxFlat = _build_round_box(tile_color, TILE_CORNER_RADIUS)

	draw_style_box(shadow_box, shadow_rect)
	draw_style_box(tile_box, tile_rect)


func _draw_face(tile_rect: Rect2) -> void:
	var center: Vector2 = tile_rect.position + tile_rect.size * Vector2(0.5, 0.56)
	var face_radius: float = tile_rect.size.x * 0.255
	var eye_radius: float = face_radius * 0.3
	var iris_radius: float = eye_radius * 0.52
	var pupil_radius: float = iris_radius * 0.5
	var eye_offset_x: float = face_radius * 0.5
	var eye_offset_y: float = face_radius * -0.1
	var left_eye_center: Vector2 = center + Vector2(-eye_offset_x, eye_offset_y)
	var right_eye_center: Vector2 = center + Vector2(eye_offset_x, eye_offset_y)
	var mouth_center: Vector2 = center + Vector2(0.0, face_radius * 0.38)
	var left_cheek_center: Vector2 = center + Vector2(-face_radius * 0.62, face_radius * 0.28)
	var right_cheek_center: Vector2 = center + Vector2(face_radius * 0.62, face_radius * 0.28)

	draw_circle(center, face_radius, FACE_FILL_COLOR)
	draw_arc(center, face_radius, 0.0, TAU, 36, FACE_LINE_COLOR, 1.3, true)
	draw_circle(left_cheek_center, face_radius * 0.22, FACE_BLUSH_COLOR)
	draw_circle(right_cheek_center, face_radius * 0.22, FACE_BLUSH_COLOR)
	draw_circle(left_eye_center, eye_radius, FACE_FILL_COLOR)
	draw_arc(left_eye_center, eye_radius, 0.0, TAU, 24, FACE_LINE_COLOR, 1.2, true)
	draw_circle(right_eye_center, eye_radius, FACE_FILL_COLOR)
	draw_arc(right_eye_center, eye_radius, 0.0, TAU, 24, FACE_LINE_COLOR, 1.2, true)
	draw_circle(left_eye_center, iris_radius, Color(0.46, 0.46, 0.46, 1.0))
	draw_circle(right_eye_center, iris_radius, Color(0.46, 0.46, 0.46, 1.0))
	draw_circle(left_eye_center, pupil_radius, FACE_LINE_COLOR)
	draw_circle(right_eye_center, pupil_radius, FACE_LINE_COLOR)
	draw_circle(
		left_eye_center + Vector2(-iris_radius * 0.28, -iris_radius * 0.28),
		iris_radius * 0.22,
		Color(1.0, 1.0, 1.0, 0.95)
	)
	draw_circle(
		right_eye_center + Vector2(-iris_radius * 0.28, -iris_radius * 0.28),
		iris_radius * 0.22,
		Color(1.0, 1.0, 1.0, 0.95)
	)
	draw_arc(
		mouth_center,
		face_radius * 0.52,
		deg_to_rad(30.0),
		deg_to_rad(150.0),
		18,
		FACE_LINE_COLOR,
		1.35,
		true
	)

func _draw_arc_label(center: Vector2, title_radius: float) -> void:
	var ring_text: String = _label_text.to_lower()
	var total_units: float = 0.0
	for index in range(ring_text.length()):
		total_units += _get_title_unit(ring_text.substr(index, 1))

	var advanced_units: float = 0.0
	for index in range(ring_text.length()):
		var character: String = ring_text.substr(index, 1)
		var unit: float = _get_title_unit(character)
		var progress: float = (advanced_units + unit * 0.5) / total_units
		advanced_units += unit
		if character == " ":
			continue

		var angle: float = lerpf(ARC_START_ANGLE, ARC_END_ANGLE, progress)
		var glyph_center: Vector2 = center + Vector2.RIGHT.rotated(angle) * title_radius
		var glyph_size: Vector2 = LABEL_FONT.get_string_size(
			character,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			ARC_FONT_SIZE
		)
		draw_set_transform(glyph_center, angle + PI * 0.5, Vector2.ONE)
		draw_string(
			LABEL_FONT,
			Vector2(
				-glyph_size.x * 0.5,
				-glyph_size.y * 0.5 + LABEL_FONT.get_ascent(ARC_FONT_SIZE)
			),
			character,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			ARC_FONT_SIZE,
			TITLE_COLOR
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _get_title_unit(character: String) -> float:
	return 0.58 if character == " " else 1.0


func _build_round_box(background_color: Color, corner_radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background_color
	box.corner_radius_top_left = corner_radius
	box.corner_radius_top_right = corner_radius
	box.corner_radius_bottom_right = corner_radius
	box.corner_radius_bottom_left = corner_radius
	return box