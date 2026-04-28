extends PanelContainer
class_name DragDropTarget

signal item_dropped(target_id: String, drag_data: Dictionary)

var datos_target: Dictionary = {}

var _title_label: Label
var _items_box: VBoxContainer


func configurar(nuevos_datos_target: Dictionary) -> void:
	datos_target = nuevos_datos_target.duplicate(true)
	custom_minimum_size = Vector2(220, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_construir_ui()
	_renderizar()


func agregar_item_colocado(texto_item: String, textura_item: Texture2D) -> void:
	if _items_box == null:
		return

	var fila: HBoxContainer = HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_child(fila)

	if textura_item != null:
		var image_rect: TextureRect = TextureRect.new()
		image_rect.custom_minimum_size = Vector2(48, 48)
		image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_rect.texture = textura_item
		image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(image_rect)

	var label_node: Label = Label.new()
	label_node.text = texto_item
	label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(label_node)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return data.get("item_node") != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	item_dropped.emit(str(datos_target.get("id", "")).strip_edges(), data as Dictionary)


func _construir_ui() -> void:
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


func _renderizar() -> void:
	if _title_label == null or _items_box == null:
		return

	_title_label.text = str(datos_target.get("label", "Target")).strip_edges()
	for child in _items_box.get_children():
		child.queue_free()
