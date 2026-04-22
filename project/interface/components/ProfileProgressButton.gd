@tool
extends Button

const LABEL_FONT := preload("res://fonts/Rubik-VariableFont_wght.ttf")

const DEFAULT_LABEL_TEXT := "Mi progreso"
const BUTTON_MIN_SIZE := Vector2(220.0, 68.0)


@onready var perfil: Sprite2D = $"TopRightAnchor/ProfileButton/Perfil"



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
	_draw()


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
	var margin := 6.0
	var padding := 12.0
	var zoom := 2.5

	var tile_size: float = minf(size.y - margin, 62.0)

	var tile_position: Vector2 = Vector2(
		size.x * 0.7 - tile_size * 0.5,
		(size.y - tile_size) * 0.5
	)

	var center: Vector2 = tile_position + Vector2(tile_size, tile_size) * 0.5

	if perfil and perfil.texture:
		var texture_size := perfil.texture.get_size().x
		var effective_size := tile_size - padding
		var base_scale := effective_size / texture_size
		var final_scale := base_scale * zoom

		perfil.scale = Vector2.ONE * final_scale
		perfil.position = center

	var seal_center: Vector2 = tile_position + Vector2(tile_size, tile_size) * Vector2(0.5, 0.55)


func _apply_empty_style_overrides() -> void:
	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("focus", empty_style)
	add_theme_stylebox_override("disabled", empty_style)
