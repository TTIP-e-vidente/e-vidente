@tool
extends Node2D

signal node_selected(selected_target: Variant)

const MapNodeDataScript := preload("res://mapas/MapNodeData.gd")
const NODE_KIND_CHAPTER := "chapter"
const NODE_KIND_QUESTION := "question"
const COLOR_COMPLETADO := Color("#db9d4b")
const COLOR_BLOQUEADO := Color(1, 1, 1, 0.35)

@export_group("Estado en Partida")
@export var nivel_id: int = 0
@export var desbloqueado: bool = false

@export_group("Destino")
@export_enum("chapter", "question") var node_kind: String = NODE_KIND_CHAPTER:
	set(value):
		_configured_node_kind = _normalize_node_kind(value)
		_refresh_preview_in_editor()
	get:
		return _configured_node_kind
@export var track_key: String = "celiaquia"
@export var level_number: int = 0
@export var question_number: int = 0
@export var question_key: String = ""

@export_group("Destino Pregunta - Avanzado")
@export_file("*.json") var question_json_path: String = ""
@export_file("*.tres") var question_resource_path: String = ""

@export_group("Vista en Editor")
@export var label_text: String = "Nodo":
	set(value):
		_configured_label_text = value.strip_edges()
		_refresh_preview_in_editor()
	get:
		return _configured_label_text
@export var icon_texture: Texture2D:
	set(value):
		_configured_icon_texture = value
		_refresh_preview_in_editor()
	get:
		return _configured_icon_texture

var base_scale: Vector2 = Vector2.ONE
var _hovered: bool = false
var _is_completed: bool = false
var _runtime_node_data: RefCounted = null
var _click_in_progress: bool = false

var _configured_node_kind: String = NODE_KIND_CHAPTER
var _configured_label_text: String = "Nodo"
var _configured_icon_texture: Texture2D = null

@onready var button: TextureButton = $Button
@onready var icon: Sprite2D = $Icon


# Ciclo de vida ---------------------------------------------------------------
func _ready() -> void:
	base_scale = scale
	_refresh_node_view()


# Escena -> contrato ---------------------------------------------------------
func build_runtime_node_data() -> RefCounted:
	var node_data: RefCounted = MapNodeDataScript.create()
	node_data.node_id = nivel_id
	node_data.node_kind = _configured_node_kind
	node_data.label_text = _resolve_label_text()
	node_data.track_key = track_key.strip_edges()
	node_data.level_number = level_number
	node_data.question_number = question_number
	node_data.question_key = question_key.strip_edges()
	node_data.question_json_path = question_json_path.strip_edges()
	node_data.question_resource_path = question_resource_path.strip_edges()
	node_data.icon_texture_path = _resolve_icon_texture_path()
	node_data.node_position = position
	return node_data


func apply_node_state(node_data: RefCounted, unlocked: bool, completed: bool = false) -> void:
	desbloqueado = unlocked
	_is_completed = completed
	_runtime_node_data = node_data.duplicate_data()
	position = node_data.node_position
	_refresh_node_view()


# Interaccion ----------------------------------------------------------------
func _on_button_pressed() -> void:
	if _click_in_progress or Engine.is_editor_hint():
		return

	var current_node_data: RefCounted = _get_current_node_data()
	if current_node_data == null or not current_node_data.has_runtime_destination():
		push_warning("LevelNode: no hay destino asignado para el nodo %d" % nivel_id)
		return

	_click_in_progress = true
	_bounce()
	await get_tree().create_timer(0.25).timeout
	node_selected.emit(current_node_data)
	_click_in_progress = false


func _on_button_mouse_entered() -> void:
	if button.disabled or _hovered or Engine.is_editor_hint():
		return
	_hovered = true
	_animate_scale_to(base_scale * 1.08)


func _on_button_mouse_exited() -> void:
	if not _hovered or Engine.is_editor_hint():
		return
	_hovered = false
	_animate_scale_to(base_scale)


func _animate_scale_to(target_scale: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target_scale, 0.12)


func _bounce() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", base_scale * Vector2(1.15, 0.90), 0.06)
	tween.tween_property(self, "scale", base_scale * Vector2(0.95, 1.05), 0.06)
	tween.tween_property(self, "scale", base_scale, 0.08)


func _apply_interaction_state() -> void:
	if not is_node_ready():
		return
	if Engine.is_editor_hint():
		button.disabled = false
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return

	button.disabled = not desbloqueado or _is_completed
	button.mouse_default_cursor_shape = (
		Control.CURSOR_ARROW
		if button.disabled
		else Control.CURSOR_POINTING_HAND
	)


# Visual ---------------------------------------------------------------------
func _refresh_preview_in_editor() -> void:
	if not is_node_ready() or not Engine.is_editor_hint():
		return
	_refresh_node_view()


func _refresh_node_view() -> void:
	if not is_node_ready():
		return

	var current_node_data: RefCounted = _get_current_node_data()
	icon.texture = _resolve_icon_texture(current_node_data)
	_apply_interaction_state()
	_apply_color_for_progress_state()


func _apply_color_for_progress_state() -> void:
	if Engine.is_editor_hint():
		modulate = Color.WHITE
		return
	if _is_completed:
		modulate = COLOR_COMPLETADO
	elif not desbloqueado:
		modulate = COLOR_BLOQUEADO
	else:
		modulate = Color.WHITE


func _get_current_node_data() -> RefCounted:
	if _runtime_node_data != null:
		return _runtime_node_data
	return build_runtime_node_data()


func _resolve_icon_texture(node_data: RefCounted) -> Texture2D:
	if node_data != null:
		var runtime_icon_path: String = str(node_data.icon_texture_path).strip_edges()
		var runtime_icon_texture: Texture2D = _load_texture_from_path(runtime_icon_path)
		if runtime_icon_texture != null:
			return runtime_icon_texture
	return _configured_icon_texture


func _resolve_label_text() -> String:
	if not _configured_label_text.is_empty():
		return _configured_label_text
	if _configured_node_kind == NODE_KIND_QUESTION:
		return "Pregunta %d" % max(1, question_number if question_number > 0 else nivel_id)
	return "Receta %d" % max(1, level_number if level_number > 0 else nivel_id)


func _resolve_icon_texture_path() -> String:
	var resolved_icon: Texture2D = _configured_icon_texture
	if resolved_icon == null:
		return ""
	return str(resolved_icon.resource_path).strip_edges()


func _load_texture_from_path(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null
	var texture_resource: Variant = load(texture_path)
	if texture_resource is Texture2D:
		return texture_resource
	return null


func _normalize_node_kind(value: String) -> String:
	return (
		NODE_KIND_QUESTION
		if value.strip_edges().to_lower() == NODE_KIND_QUESTION
		else NODE_KIND_CHAPTER
	)
