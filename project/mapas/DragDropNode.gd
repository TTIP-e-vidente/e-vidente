extends Control

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DEFAULT_RETURN_SCENE_PATH := GameSceneRouter.MAP_SCENE_PATH
const DRAG_DROP_MODE := "drag_drop"

const FEEDBACK_INFO_COLOR := Color.WHITE
const FEEDBACK_SUCCESS_COLOR := Color(0.23, 0.72, 0.32)
const FEEDBACK_ERROR_COLOR := Color(0.82, 0.26, 0.26)


class DragDropItem extends PanelContainer:
	var item_data: Dictionary = {}
	var owner_scene: Node = null

	func _ready() -> void:
		custom_minimum_size = Vector2(180, 140)

		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		add_child(margin)

		var box: VBoxContainer = VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(box)

		var image_rect: TextureRect = TextureRect.new()
		image_rect.custom_minimum_size = Vector2(72, 72)
		image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture: Texture2D = _load_texture()
		if texture != null:
			image_rect.texture = texture
			box.add_child(image_rect)

		var label_node: Label = Label.new()
		label_node.text = str(item_data.get("label", "Item")).strip_edges()
		label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label_node)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if owner_scene == null:
			return null
		if bool(item_data.get("placed", false)):
			return null

		var preview: Control = duplicate() as Control
		if preview != null:
			preview.modulate = Color(1, 1, 1, 0.75)
			set_drag_preview(preview)

		return {
			"item_id": str(item_data.get("id", "")).strip_edges(),
			"label": str(item_data.get("label", "")).strip_edges(),
			"image": str(item_data.get("image", "")).strip_edges(),
			"correct_target": str(item_data.get("correct_target", "")).strip_edges(),
			"item_node": self
		}

	func mark_as_placed() -> void:
		item_data["placed"] = true
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _load_texture() -> Texture2D:
		var image_path: String = str(item_data.get("image", "")).strip_edges()
		if image_path.is_empty():
			return null
		var resource: Variant = load(image_path)
		if resource is Texture2D:
			return resource as Texture2D
		push_warning("DragDropNode: item image invalida (%s)." % image_path)
		return null


class DragDropTarget extends PanelContainer:
	var target_data: Dictionary = {}
	var owner_scene: Node = null
	var items_box: VBoxContainer

	func _ready() -> void:
		custom_minimum_size = Vector2(220, 220)

		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		add_child(margin)

		var root_box: VBoxContainer = VBoxContainer.new()
		root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(root_box)

		var title_label: Label = Label.new()
		title_label.text = str(target_data.get("label", "Target")).strip_edges()
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_box.add_child(title_label)

		items_box = VBoxContainer.new()
		items_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		items_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_box.add_child(items_box)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if owner_scene == null:
			return false
		return bool(owner_scene.call("_can_drop_item_on_target", _get_target_id(), data))

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if owner_scene == null:
			return
		owner_scene.call("_drop_item_on_target", _get_target_id(), data)

	func add_placed_item(item_label: String, item_texture: Texture2D) -> void:
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_box.add_child(row)

		if item_texture != null:
			var image_rect: TextureRect = TextureRect.new()
			image_rect.custom_minimum_size = Vector2(48, 48)
			image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image_rect.texture = item_texture
			image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(image_rect)

		var label_node: Label = Label.new()
		label_node.text = item_label
		label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label_node)

	func _get_target_id() -> String:
		return str(target_data.get("id", "")).strip_edges()


var track_key: String = "celiaquia"
var _active_question_key: String = ""
var _has_map_session: bool = false
var _return_scene_path: String = DEFAULT_RETURN_SCENE_PATH
var _activity_completed: bool = false
var _blocking_error_message: String = ""
var _node_data: Dictionary = {}
var _content: Dictionary = {}
var _target_controls_by_id: Dictionary = {}
var _required_item_ids: Array[String] = []
var _placed_item_ids: Dictionary = {}

@onready var _title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var _instruction_label: Label = $MarginContainer/PanelContainer/VBoxContainer/InstructionLabel
@onready var _targets_container: HBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/TargetsContainer
@onready var _items_grid: GridContainer = $MarginContainer/PanelContainer/VBoxContainer/ItemsGrid
@onready var _feedback_label: Label = $MarginContainer/PanelContainer/VBoxContainer/FeedbackLabel
@onready var _continue_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonsRow/ContinueButton


func _ready() -> void:
	_setup_from_active_session()
	if not _blocking_error_message.is_empty():
		_show_blocking_error(_blocking_error_message)
		return
	_render_activity()


func _setup_from_active_session() -> void:
	_reset_runtime_state()

	var session_context: Dictionary = Global.obtener_activo_pregunta_sesion()
	if session_context.is_empty():
		_set_blocking_error_message("No hay una sesion activa para este nodo drag_drop.")
		return

	var node_data: Dictionary = _read_session_node_data(session_context)
	setup_from_node_data(node_data, session_context)


func setup_from_node_data(node_data: Dictionary, session_context: Dictionary) -> bool:
	# Formato oficial despues del loader: {id, theme, title, difficulty, mode, content}
	_apply_session_context(session_context)
	if node_data.is_empty():
		_set_blocking_error_message("El nodo drag_drop no recibio node_data normalizado.")
		return false
	if str(node_data.get("mode", "")).strip_edges() != DRAG_DROP_MODE:
		_set_blocking_error_message("La escena DragDropNode solo soporta mode drag_drop.")
		return false

	_node_data = node_data.duplicate(true)
	_content = _node_data.get("content", {})

	var content_error: String = _validate_runtime_content(_content)
	if not content_error.is_empty():
		_set_blocking_error_message(content_error)
		return false

	_required_item_ids = _collect_required_item_ids(_content.get("items", []))
	_continue_button.disabled = true
	return true


func _reset_runtime_state() -> void:
	_active_question_key = ""
	_has_map_session = false
	_return_scene_path = DEFAULT_RETURN_SCENE_PATH
	_activity_completed = false
	_blocking_error_message = ""
	_node_data = {}
	_content = {}
	_target_controls_by_id.clear()
	_required_item_ids.clear()
	_placed_item_ids.clear()


func _apply_session_context(session_state: Dictionary) -> void:
	track_key = str(session_state.get("track_key", track_key)).strip_edges()
	_active_question_key = str(session_state.get("question_key", "")).strip_edges()
	_return_scene_path = str(
		session_state.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _return_scene_path.is_empty():
		_return_scene_path = DEFAULT_RETURN_SCENE_PATH
	_has_map_session = not session_state.is_empty()


func _read_session_node_data(session_context: Dictionary) -> Dictionary:
	var raw_node_data: Variant = session_context.get("node_content", {})
	if raw_node_data is Dictionary:
		return (raw_node_data as Dictionary).duplicate(true)
	return {}


func _validate_runtime_content(content: Dictionary) -> String:
	var target_ids: Array[String] = []
	var raw_targets: Array = content.get("targets", [])
	for raw_target in raw_targets:
		var target: Dictionary = raw_target as Dictionary
		var target_id: String = str(target.get("id", "")).strip_edges()
		if target_ids.has(target_id):
			return "DragDrop: hay targets repetidos (%s)." % target_id
		target_ids.append(target_id)

	var has_correct_items: bool = false
	var seen_item_ids: Array[String] = []
	var raw_items: Array = content.get("items", [])
	for raw_item in raw_items:
		var item: Dictionary = raw_item as Dictionary
		var item_id: String = str(item.get("id", "")).strip_edges()
		if seen_item_ids.has(item_id):
			return "DragDrop: hay items repetidos (%s)." % item_id
		seen_item_ids.append(item_id)

		var correct_target: String = str(item.get("correct_target", "")).strip_edges()
		if correct_target.is_empty():
			continue
		has_correct_items = true
		if not target_ids.has(correct_target):
			return "DragDrop: el item %s apunta a un target inexistente (%s)." % [item_id, correct_target]

	if not has_correct_items:
		return "DragDrop: no hay items correctos para completar la actividad."

	return ""


func _collect_required_item_ids(raw_items: Array) -> Array[String]:
	var required_item_ids: Array[String] = []
	for raw_item in raw_items:
		var item: Dictionary = raw_item as Dictionary
		var correct_target: String = str(item.get("correct_target", "")).strip_edges()
		if correct_target.is_empty():
			continue
		required_item_ids.append(str(item.get("id", "")).strip_edges())
	return required_item_ids


func _render_activity() -> void:
	_title_label.text = str(_node_data.get("title", "Nodo drag_drop")).strip_edges()
	_instruction_label.text = str(_content.get("instruction", "")).strip_edges()
	_set_feedback(_instruction_label.text, FEEDBACK_INFO_COLOR)
	_render_targets()
	_render_items()


func _render_targets() -> void:
	_clear_container(_targets_container)
	_target_controls_by_id.clear()

	var raw_targets: Array = _content.get("targets", [])
	for raw_target in raw_targets:
		var target_control: DragDropTarget = DragDropTarget.new()
		target_control.target_data = (raw_target as Dictionary).duplicate(true)
		target_control.owner_scene = self
		target_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_targets_container.add_child(target_control)
		_target_controls_by_id[str(target_control.target_data.get("id", "")).strip_edges()] = target_control


func _render_items() -> void:
	_clear_container(_items_grid)

	var raw_items: Array = _content.get("items", [])
	for raw_item in raw_items:
		var item_control: DragDropItem = DragDropItem.new()
		item_control.item_data = (raw_item as Dictionary).duplicate(true)
		item_control.owner_scene = self
		_items_grid.add_child(item_control)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _can_drop_item_on_target(target_id: String, data: Variant) -> bool:
	if _activity_completed:
		return false
	if not _target_controls_by_id.has(target_id):
		return false
	if not data is Dictionary:
		return false
	var item_node: DragDropItem = data.get("item_node") as DragDropItem
	if item_node == null:
		return false
	return not bool(item_node.item_data.get("placed", false))


func _drop_item_on_target(target_id: String, data: Variant) -> void:
	if not _can_drop_item_on_target(target_id, data):
		return

	var item_node: DragDropItem = data.get("item_node") as DragDropItem
	if item_node == null:
		return

	var correct_target: String = str(data.get("correct_target", "")).strip_edges()
	if correct_target != target_id or correct_target.is_empty():
		_set_feedback(_get_error_message(), FEEDBACK_ERROR_COLOR)
		return

	var item_id: String = str(data.get("item_id", "")).strip_edges()
	_placed_item_ids[item_id] = true
	item_node.mark_as_placed()

	var target_control: DragDropTarget = _target_controls_by_id.get(target_id) as DragDropTarget
	if target_control != null:
		target_control.add_placed_item(
			str(data.get("label", "")).strip_edges(),
			_load_item_texture(str(data.get("image", "")).strip_edges())
		)

	_set_feedback(_get_success_message(), FEEDBACK_SUCCESS_COLOR)
	_update_completion_state()


func _update_completion_state() -> void:
	for required_item_id in _required_item_ids:
		if not bool(_placed_item_ids.get(required_item_id, false)):
			return

	_activity_completed = true
	_continue_button.disabled = false
	_set_feedback(_get_success_message(), FEEDBACK_SUCCESS_COLOR)


func _load_item_texture(image_path: String) -> Texture2D:
	if image_path.is_empty():
		return null
	var resource: Variant = load(image_path)
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("DragDropNode: item image invalida (%s)." % image_path)
	return null


func _get_success_message() -> String:
	var success_message: String = str(_content.get("success_message", "")).strip_edges()
	if success_message.is_empty():
		return "Bien! Ese item va en ese target."
	return success_message


func _get_error_message() -> String:
	var error_message: String = str(_content.get("error_message", "")).strip_edges()
	if error_message.is_empty():
		return "Ese item no corresponde a ese target."
	return error_message


func _set_feedback(message: String, feedback_color: Color) -> void:
	_feedback_label.text = message.strip_edges()
	_feedback_label.modulate = feedback_color


func _show_blocking_error(message: String) -> void:
	_title_label.text = "Contenido no disponible"
	_instruction_label.text = message
	_set_feedback(message, FEEDBACK_ERROR_COLOR)
	_targets_container.hide()
	_items_grid.hide()
	_continue_button.disabled = true


func _finish_activity_if_completed() -> void:
	if not _activity_completed:
		return
	if _has_map_session and not _active_question_key.is_empty():
		Global.marcar_pregunta_completado(track_key, _active_question_key)
	SaveManager.registrar_sesion_preguntas_completada(_required_item_ids.size(), _required_item_ids.size())


func _return_to_map() -> void:
	Global.limpiar_activo_pregunta_sesion()
	get_tree().change_scene_to_file(_return_scene_path)


func _set_blocking_error_message(message: String) -> void:
	var clean_message: String = message.strip_edges()
	if clean_message.is_empty():
		return
	if not _blocking_error_message.is_empty():
		return
	_blocking_error_message = clean_message


func _on_back_button_pressed() -> void:
	_finish_activity_if_completed()
	_return_to_map()


func _on_continue_button_pressed() -> void:
	if not _activity_completed:
		return
	_finish_activity_if_completed()
	_return_to_map()
