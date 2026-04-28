extends PanelContainer
class_name DragDropTarget

# Responsabilidad:
# - Representar visualmente un target.
# - Aceptar drops validos a nivel UI.
# - Avisar al nodo principal que se solto un item.
# - Mostrar items colocados.
# No hace:
# - No valida si el item es correcto para la actividad.
# - No actualiza progreso global.
# - No conoce el mapa.

signal item_dropped(target_id: String, drag_data: Dictionary)

var target_data: Dictionary = {}

var _title_label: Label
var _items_box: VBoxContainer


func setup(new_target_data: Dictionary) -> void:
	target_data = new_target_data.duplicate(true)
	custom_minimum_size = Vector2(220, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_construir_ui_si_hace_falta()
	_actualizar_ui()


func add_placed_item(item_label: String, item_texture: Texture2D) -> void:
	if _items_box == null:
		return

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_child(row)

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


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return data.get("item_node") != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	item_dropped.emit(_obtener_id_target(), data as Dictionary)


func _obtener_id_target() -> String:
	return str(target_data.get("id", "")).strip_edges()


func _construir_ui_si_hace_falta() -> void:
	if _title_label != null and _items_box != null:
		return

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

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(_title_label)

	_items_box = VBoxContainer.new()
	_items_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(_items_box)


func _actualizar_ui() -> void:
	if _title_label == null or _items_box == null:
		return

	_title_label.text = str(target_data.get("label", "Target")).strip_edges()
	for child in _items_box.get_children():
		child.queue_free()
