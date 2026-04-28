extends PanelContainer
class_name DragDropItem

# Responsabilidad:
# - Representar visualmente un item arrastrable.
# - Guardar `item_data`.
# - Generar `drag_data`.
# - Marcarse como colocado.
# No hace:
# - No valida la actividad completa.
# - No conoce el progreso del mapa.
# - No decide si el drop es correcto.

var item_data: Dictionary = {}

var _label_node: Label
var _image_rect: TextureRect


func setup(new_item_data: Dictionary) -> void:
	item_data = new_item_data.duplicate(true)
	custom_minimum_size = Vector2(180, 140)
	_construir_ui_si_hace_falta()
	_actualizar_ui()


func mark_as_placed() -> void:
	item_data["placed"] = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_drag_data(_at_position: Vector2) -> Variant:
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


func _construir_ui_si_hace_falta() -> void:
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


func _actualizar_ui() -> void:
	if _label_node == null or _image_rect == null:
		return

	var texture: Texture2D = _cargar_textura()
	_image_rect.texture = texture
	_image_rect.visible = texture != null
	_label_node.text = str(item_data.get("label", "Item")).strip_edges()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _cargar_textura() -> Texture2D:
	var image_path: String = str(item_data.get("image", "")).strip_edges()
	if image_path.is_empty():
		return null

	var resource: Variant = load(image_path)
	if resource is Texture2D:
		return resource as Texture2D

	push_warning("DragDropItem: item image invalida (%s)." % image_path)
	return null
