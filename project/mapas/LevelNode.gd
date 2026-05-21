# HELPER_INTERNO
# Nodo visual individual del mapa (estrella/candado/completado).
# Solo renderiza estado — no decide flujo.
@tool
extends Node2D

signal selected(node_data: MapNodeData)

const COLOR_AVAILABLE := Color(1.0, 0.96, 0.84, 1.0)
const COLOR_COMPLETED := Color("#db9d4b")
const COLOR_LOCKED := Color(1, 1, 1, 0.28)
const STATE_COMPLETED := "completed"
const STATE_AVAILABLE := "available"
const STATE_LOCKED := "locked"

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
@export var can_play: bool = false:
	set(value):
		can_play = value
		update_view()
@export_enum("completed", "available", "locked") var visual_state: String = STATE_LOCKED:
	set(value):
		visual_state = _sanitize_visual_state(value)
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
var _disponible_tween: Tween = null
var _best_accuracy: float = 0.0

@onready var button: TextureButton = $Button
@onready var state_icon: Sprite2D = $Icon
@onready var title_label: Label = get_node_or_null("TitleLabel") as Label
@onready var star_progress: Node2D = get_node_or_null("StarProgress")


func _ready() -> void:
	_base_scale = scale
	update_view()


func configurar(
	data: MapNodeData,
	progress_state: Variant = {},
	is_completed: bool = false
) -> void:
	node_data = data
	if progress_state is Dictionary:
		_apply_progress_state(progress_state as Dictionary)
	else:
		_apply_legacy_progress_state(bool(progress_state), is_completed)
	update_view()


func update_view() -> void:
	if not is_node_ready():
		return

	state_icon.texture = icon_texture
	if title_label != null:
		title_label.text = _get_title()
	if button != null:
		button.tooltip_text = ""
		button.disabled = _is_button_disabled()
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW
			if button.disabled
			else Control.CURSOR_POINTING_HAND
		)
	_apply_state_color()
	_refresh_star_progress()


func _refresh_star_progress() -> void:
	if star_progress == null or Engine.is_editor_hint():
		return
	if star_progress.has_method("set_progress"):
		star_progress.call("set_progress", _best_accuracy / 100.0)


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
	_animar_escala_hasta(_base_scale * 1.08)


func _on_button_mouse_exited() -> void:
	if Engine.is_editor_hint() or not _is_hovering:
		return
	_is_hovering = false
	_animar_escala_hasta(_base_scale)


func _get_title() -> String:
	if node_data != null and not node_data.title.is_empty():
		return node_data.title
	if not label_text.is_empty():
		return label_text
	return name


func _is_button_disabled() -> bool:
	return not Engine.is_editor_hint() and not can_play


func _apply_state_color() -> void:
	if Engine.is_editor_hint():
		modulate = Color.WHITE
	else:
		match visual_state:
			STATE_COMPLETED:
				_cancelar_tween_disponible()
				modulate = COLOR_COMPLETED
			STATE_LOCKED:
				_cancelar_tween_disponible()
				modulate = COLOR_LOCKED
			_:
				modulate = COLOR_AVAILABLE
				_animar_disponible()


func _apply_progress_state(progress_state: Dictionary) -> void:
	var is_unlocked: bool = bool(progress_state.get("is_unlocked", false))
	var is_completed: bool = bool(progress_state.get("is_completed", false))
	unlocked = is_unlocked
	completed = is_completed
	can_play = bool(progress_state.get("can_play", is_unlocked or is_completed))
	visual_state = _resolve_visual_state_name(
		is_unlocked,
		is_completed,
		str(progress_state.get("visual_state", ""))
	)
	_best_accuracy = float(progress_state.get("best_accuracy", 0.0))


func _apply_legacy_progress_state(is_unlocked: bool, is_completed: bool) -> void:
	unlocked = is_unlocked
	completed = is_completed
	can_play = is_unlocked or is_completed
	visual_state = _resolve_visual_state_name(is_unlocked, is_completed)


func _resolve_visual_state_name(
	is_unlocked: bool,
	is_completed: bool,
	state_name: String = ""
) -> String:
	var clean_state_name: String = state_name.strip_edges()
	if not clean_state_name.is_empty():
		return _sanitize_visual_state(clean_state_name)
	if is_completed:
		return STATE_COMPLETED
	if is_unlocked:
		return STATE_AVAILABLE
	return STATE_LOCKED


func _sanitize_visual_state(state_name: String) -> String:
	match state_name.strip_edges():
		STATE_COMPLETED:
			return STATE_COMPLETED
		STATE_AVAILABLE:
			return STATE_AVAILABLE
		_:
			return STATE_LOCKED


func _cancelar_tween_disponible() -> void:
	if _disponible_tween != null:
		_disponible_tween.kill()
	_disponible_tween = null


func _animar_disponible() -> void:
	_cancelar_tween_disponible()
	_disponible_tween = create_tween()
	_disponible_tween.set_trans(Tween.TRANS_BACK)
	_disponible_tween.set_ease(Tween.EASE_OUT)
	_disponible_tween.tween_property(self, "scale", _base_scale * 1.18, 0.4)
	_disponible_tween.tween_property(self, "scale", _base_scale, 0.3)


func _animar_escala_hasta(escala_destino: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", escala_destino, 0.12)


func _animate_click() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale * Vector2(1.15, 0.90), 0.06)
	tween.tween_property(self, "scale", _base_scale * Vector2(0.95, 1.05), 0.06)
	tween.tween_property(self, "scale", _base_scale, 0.08)
