extends PanelContainer
class_name DragDropItem

var datos_item: Dictionary = {}

var _label_node: Label
var _image_rect: TextureRect


func configurar(nuevos_datos_item: Dictionary) -> void:
	datos_item = nuevos_datos_item.duplicate(true)
	custom_minimum_size = Vector2(180, 140)
	_construir_ui()
	_renderizar()


func marcar_como_colocado() -> void:
	datos_item["placed"] = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_drag_data(_at_position: Vector2) -> Variant:
	if bool(datos_item.get("placed", false)):
		return null

	_mostrar_preview_de_arrastre()

	return {
		"item_id": str(datos_item.get("id", "")).strip_edges(),
		"label": str(datos_item.get("label", "")).strip_edges(),
		"image": str(datos_item.get("image", "")).strip_edges(),
		"correct_target": str(datos_item.get("correct_target", "")).strip_edges(),
		"item_node": self
	}


func _mostrar_preview_de_arrastre() -> void:
	var preview: Control = duplicate() as Control
	if preview == null:
		return
	preview.modulate = Color(1, 1, 1, 0.75)
	set_drag_preview(preview)


func _construir_ui() -> void:
	if _label_node != null and _image_rect != null:
		return

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

	_image_rect = TextureRect.new()
	_image_rect.custom_minimum_size = Vector2(72, 72)
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_image_rect)

	_label_node = Label.new()
	_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label_node)


func _renderizar() -> void:
	if _label_node == null or _image_rect == null:
		return

	var image_path: String = str(datos_item.get("image", "")).strip_edges()
	var texture: Texture2D = load(image_path) as Texture2D if not image_path.is_empty() else null
	_image_rect.texture = texture
	_image_rect.visible = texture != null
	_label_node.text = str(datos_item.get("label", "Item")).strip_edges()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
