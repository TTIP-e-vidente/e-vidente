@tool
extends Node2D

signal selected(node_data: MapNodeData)

const COLOR_COMPLETED := Color("#db9d4b")
const COLOR_LOCKED := Color(1, 1, 1, 0.35)

@export_group("Runtime")
@export var nivel_id: int = 0
@export var unlocked: bool = false:
	set(value):
		unlocked = value
		update_view()
@export var completed: bool = false:
	set(value):
		completed = value
		update_view()

@export_group("Scene Compatibility")
@export_enum("chapter", "question") var node_kind: String = "chapter"
@export var level_number: int = 0
@export var question_number: int = 0
@export var node_key: String = ""
@export var label_text: String = "Nodo":
	set(value):
		label_text = value.strip_edges()
		update_view()

@export_group("View")
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		update_view()

var node_data: MapNodeData = null
var _base_scale: Vector2 = Vector2.ONE
var _is_hovering: bool = false
var _click_in_progress: bool = false

@onready var button: TextureButton = $Button
@onready var state_icon: Sprite2D = $Icon
@onready var title_label: Label = get_node_or_null("TitleLabel") as Label


func _ready() -> void:
	_base_scale = scale
	update_view()


func setup(data: MapNodeData, is_unlocked: bool, is_completed: bool = false) -> void:
	node_data = data
	unlocked = is_unlocked
	completed = is_completed
	update_view()


func configurar(data: MapNodeData, is_unlocked: bool, is_completed: bool = false) -> void:
	setup(data, is_unlocked, is_completed)


func update_view() -> void:
	if not is_node_ready():
		return

	state_icon.texture = icon_texture
	if title_label != null:
		title_label.text = _get_title()
	if button != null:
		button.tooltip_text = _get_title()
		button.disabled = _is_button_disabled()
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW
			if button.disabled
			else Control.CURSOR_POINTING_HAND
		)
	_apply_state_color()


func _on_button_pressed() -> void:
	if _click_in_progress or Engine.is_editor_hint() or _is_button_disabled():
		return
	if node_data == null:
		return

	_click_in_progress = true
	_animate_click()
	await get_tree().create_timer(0.25).timeout
	selected.emit(node_data)
	_click_in_progress = false


func _on_button_mouse_entered() -> void:
	if Engine.is_editor_hint() or _is_hovering or _is_button_disabled():
		return
	_is_hovering = true
	_animate_scale_to(_base_scale * 1.08)


func _on_button_mouse_exited() -> void:
	if Engine.is_editor_hint() or not _is_hovering:
		return
	_is_hovering = false
	_animate_scale_to(_base_scale)


func _get_title() -> String:
	if node_data != null and not node_data.title.is_empty():
		return node_data.title
	if not label_text.is_empty():
		return label_text
	return name


func _is_button_disabled() -> bool:
	return not Engine.is_editor_hint() and (not unlocked or completed)


func _apply_state_color() -> void:
	if Engine.is_editor_hint():
		modulate = Color.WHITE
	elif completed:
		modulate = COLOR_COMPLETED
	elif not unlocked:
		modulate = COLOR_LOCKED
	else:
		modulate = Color.WHITE


func _animate_scale_to(target_scale: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target_scale, 0.12)


func _animate_click() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * Vector2(1.15, 0.90), 0.06)
	tween.tween_property(self, "scale", _base_scale * Vector2(0.95, 1.05), 0.06)
	tween.tween_property(self, "scale", _base_scale, 0.08)
