@tool
extends Node2D

signal level_selected(level_target: Variant)

const MapNodeDataScript := preload("res://mapas/MapNodeData.gd")
const NODE_KIND_CHAPTER := "chapter"
const NODE_KIND_QUESTION := "question"
const COLOR_COMPLETADO := Color("#db9d4b")
const COLOR_BLOQUEADO := Color(1, 1, 1, 0.35)

@export_group("Runtime")
@export var nivel_id: int = 0
@export var desbloqueado: bool = false

@export_group("Map Authoring")
@export_enum("chapter", "question") var node_kind: String = NODE_KIND_CHAPTER:
	set(value):
		_authored_node_kind = _normalize_node_kind(value)
		_sync_authored_preview()
	get:
		return _authored_node_kind
@export var track_key: String = "celiaquia"
@export var level_number: int = 0
@export var question_number: int = 0
@export var question_key: String = ""
@export_file("*.tres") var question_resource_path: String = ""
@export_file("*.tscn") var scene_path: String = ""

@export_group("Visual")
@export var label_text: String = "Nodo":
	set(value):
		_authored_label_text = value.strip_edges()
		_sync_authored_preview()
	get:
		return _authored_label_text
@export var icon_texture: Texture2D:
	set(value):
		_authored_icon_texture = value
		_sync_authored_preview()
	get:
		return _authored_icon_texture

var base_scale: Vector2 = Vector2.ONE
var _hovered: bool = false
var _node_is_completed: bool = false
var _node_label_text: String = ""
var _node_icon_texture: Texture2D = null
var _selected_node_data: Variant = null
var _selection_in_progress: bool = false

var _authored_node_kind: String = NODE_KIND_CHAPTER
var _authored_label_text: String = "Nodo"
var _authored_icon_texture: Texture2D = null

@onready var button: TextureButton = $Button
@onready var icon: Sprite2D = $Icon
@onready var title_label: Label = $Title


# Ciclo de vida ---------------------------------------------------------------
func _ready() -> void:
	base_scale = scale
	_apply_authored_preview_state()
	_selected_node_data = build_node_data()
	_refresh_node_view()


# Escena -> contrato ---------------------------------------------------------
func build_node_data() -> RefCounted:
	var node_data = MapNodeDataScript.new()
	node_data.node_id = nivel_id
	node_data.node_kind = _authored_node_kind
	node_data.label_text = _resolved_authored_label_text()
	node_data.track_key = track_key.strip_edges()
	node_data.level_number = level_number
	node_data.question_number = question_number
	node_data.question_key = question_key.strip_edges()
	node_data.question_resource_path = question_resource_path.strip_edges()
	node_data.scene_path = _resolve_scene_path()
	node_data.icon_texture_path = _resolve_authored_icon_texture_path()
	node_data.node_position = position
	return node_data


func setup_from_node_data(node_data, unlocked: bool, completed: bool = false) -> void:
	desbloqueado = unlocked
	_node_is_completed = completed
	_copy_runtime_data_from_node_data(node_data)
	_selected_node_data = node_data.duplicate_data()
	_refresh_node_view()


# Interaccion ----------------------------------------------------------------
func _on_button_pressed() -> void:
	if _selection_in_progress or Engine.is_editor_hint():
		return
	if not _node_has_target():
		push_warning("LevelNode: no hay destino asignado para el nodo %d" % nivel_id)
		return
	_selection_in_progress = true
	_bounce()
	await get_tree().create_timer(0.25).timeout
	level_selected.emit(_selected_node_data)
	_selection_in_progress = false


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
	button.disabled = not desbloqueado or _node_is_completed
	button.mouse_default_cursor_shape = (
		Control.CURSOR_ARROW
		if button.disabled
		else Control.CURSOR_POINTING_HAND
	)


# Visual ---------------------------------------------------------------------
func _apply_authored_preview_state() -> void:
	_node_label_text = _resolved_authored_label_text()
	_node_icon_texture = _resolve_authored_icon_texture()


func _sync_authored_preview() -> void:
	if not is_node_ready() or not Engine.is_editor_hint():
		return
	_apply_authored_preview_state()
	_selected_node_data = build_node_data()
	_refresh_node_view()


func _copy_runtime_data_from_node_data(node_data) -> void:
	nivel_id = node_data.node_id
	_authored_node_kind = _normalize_node_kind(node_data.node_kind)
	track_key = node_data.track_key
	level_number = node_data.level_number
	question_number = node_data.question_number
	question_key = node_data.question_key
	question_resource_path = node_data.question_resource_path
	scene_path = node_data.scene_path
	position = node_data.node_position
	_authored_label_text = node_data.label_text
	_node_label_text = node_data.label_text
	_authored_icon_texture = _resolve_runtime_icon_texture(node_data.icon_texture_path)
	_node_icon_texture = _authored_icon_texture


func _refresh_node_view() -> void:
	_apply_node_visuals()
	_apply_interaction_state()
	_apply_color_for_progress_state()


func _apply_node_visuals() -> void:
	if not is_node_ready():
		return
	title_label.text = _node_label_text
	icon.texture = _node_icon_texture


func _apply_color_for_progress_state() -> void:
	if Engine.is_editor_hint():
		modulate = Color.WHITE
		return
	if _node_is_completed:
		modulate = COLOR_COMPLETADO
	elif not desbloqueado:
		modulate = COLOR_BLOQUEADO
	else:
		modulate = Color.WHITE


func _resolve_runtime_icon_texture(icon_texture_path: String) -> Texture2D:
	var runtime_texture: Texture2D = _load_texture_from_path(icon_texture_path.strip_edges())
	if runtime_texture != null:
		return runtime_texture
	return _resolve_authored_icon_texture()


func _resolve_scene_path() -> String:
	return scene_path.strip_edges()


func _resolved_authored_label_text() -> String:
	if not _authored_label_text.is_empty():
		return _authored_label_text
	if _authored_node_kind == NODE_KIND_QUESTION:
		return "Pregunta %d" % max(1, question_number if question_number > 0 else nivel_id)
	return "Receta %d" % max(1, level_number if level_number > 0 else nivel_id)


func _resolve_authored_icon_texture() -> Texture2D:
	return _authored_icon_texture


func _resolve_authored_icon_texture_path() -> String:
	var resolved_icon: Texture2D = _resolve_authored_icon_texture()
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


# Destino --------------------------------------------------------------------
func _node_has_target() -> bool:
	if _selected_node_data == null:
		return false
	if _selected_node_data.is_question():
		return _selected_node_data.has_question_destination()
	return _selected_node_data.has_chapter_destination()
	return false
