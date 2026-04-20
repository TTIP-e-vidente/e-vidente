extends Node2D

signal level_selected(level_target: Variant)

@export var nivel_id: int = 0
@export var escena: String = ""
@export var desbloqueado: bool = false

const CLICK_RADIUS := 80.0
const COLOR_COMPLETADO := Color("#db9d4b")  # naranja tierra de la paleta
const COLOR_BLOQUEADO := Color(1, 1, 1, 0.35)

var base_scale := Vector2.ONE
var _hovered: bool = false
var _node_completed: bool = false
var _node_label_text: String = ""
var _node_icon_texture_path: String = ""
var _node_target_payload: Variant = null

@onready var icon: Sprite2D = $Button/Icon
@onready var title_label: Label = $Title


func _ready() -> void:
	base_scale = scale
	_apply_node_visuals()
	_apply_color_for_progress_state()


func _input(event: InputEvent) -> void:
	if not desbloqueado or _node_completed:
		return

	if event is InputEventMouseMotion:
		_update_hover_state(event.global_position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_inside(event.global_position):
			_on_click()


func _on_click() -> void:
	if not _node_has_target():
		push_warning("LevelNode: no hay destino asignado para el nodo %d" % nivel_id)
		return
	_bounce()
	await get_tree().create_timer(0.25).timeout
	level_selected.emit(_node_target_payload)


func _is_inside(mouse_pos: Vector2) -> bool:
	return global_position.distance_to(mouse_pos) <= CLICK_RADIUS * scale.x


func setup(node_definition: Dictionary, unlocked: bool, completed: bool = false) -> void:
	# El mapa ya resolvio el contenido del nodo; aca solo lo guardamos para la vista.
	nivel_id = int(node_definition.get("id", nivel_id))
	escena = str(node_definition.get("scene_path", node_definition.get("scene", escena))).strip_edges()
	desbloqueado = unlocked
	_node_completed = completed
	_node_label_text = str(node_definition.get("label", "")).strip_edges()
	_node_icon_texture_path = str(node_definition.get("icon_texture_path", "")).strip_edges()
	_node_target_payload = node_definition.duplicate(true)
	_apply_node_visuals()
	_apply_color_for_progress_state()


func _update_hover_state(mouse_position: Vector2) -> void:
	var mouse_is_over_node: bool = _is_inside(mouse_position)
	if mouse_is_over_node and not _hovered:
		_hovered = true
		_animate_scale_to(base_scale * 1.08)
	elif not mouse_is_over_node and _hovered:
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


func _apply_color_for_progress_state() -> void:
	if _node_completed:
		modulate = COLOR_COMPLETADO
	elif not desbloqueado:
		modulate = COLOR_BLOQUEADO
	else:
		modulate = Color.WHITE


func _apply_node_visuals() -> void:
	if not is_node_ready():
		return

	title_label.text = _node_label_text

	if _node_icon_texture_path.is_empty():
		icon.texture = null
		return

	var texture_resource: Variant = load(_node_icon_texture_path)
	if texture_resource is Texture2D:
		icon.texture = texture_resource


func _node_has_target() -> bool:
	if _node_target_payload is Dictionary:
		return not (_node_target_payload as Dictionary).is_empty()
	return not str(_node_target_payload).strip_edges().is_empty()
