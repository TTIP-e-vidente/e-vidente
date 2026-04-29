extends PanelContainer
class_name DragDropTarget

signal item_dropped(target_id: String, drag_data: Dictionary)

var datos_target: Dictionary = {}

var _titulo_target: Label
var _contenedor_items: VBoxContainer


func configurar(nuevos_datos_target: Dictionary) -> void:
	datos_target = nuevos_datos_target.duplicate(true)
	custom_minimum_size = Vector2(220, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_construir_ui()
	_renderizar()


func agregar_item_colocado(texto_item: String, textura_item: Texture2D) -> void:
	if _contenedor_items == null:
		return

	var fila: HBoxContainer = HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenedor_items.add_child(fila)

	if textura_item != null:
		var imagen_item: TextureRect = TextureRect.new()
		imagen_item.custom_minimum_size = Vector2(48, 48)
		imagen_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagen_item.texture = textura_item
		imagen_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(imagen_item)

	var etiqueta_item: Label = Label.new()
	etiqueta_item.text = texto_item
	etiqueta_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(etiqueta_item)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return data.get("item_node") != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	item_dropped.emit(str(datos_target.get("id", "")).strip_edges(), data as Dictionary)


func _construir_ui() -> void:
	if _titulo_target != null and _contenedor_items != null:
		return

	var contenedor_margen: MarginContainer = MarginContainer.new()
	contenedor_margen.add_theme_constant_override("margin_left", 12)
	contenedor_margen.add_theme_constant_override("margin_top", 12)
	contenedor_margen.add_theme_constant_override("margin_right", 12)
	contenedor_margen.add_theme_constant_override("margin_bottom", 12)
	add_child(contenedor_margen)

	var contenedor_raiz: VBoxContainer = VBoxContainer.new()
	contenedor_raiz.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor_margen.add_child(contenedor_raiz)

	_titulo_target = Label.new()
	_titulo_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor_raiz.add_child(_titulo_target)

	_contenedor_items = VBoxContainer.new()
	_contenedor_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenedor_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor_raiz.add_child(_contenedor_items)


func _renderizar() -> void:
	if _titulo_target == null or _contenedor_items == null:
		return

	_titulo_target.text = str(datos_target.get("label", "Target")).strip_edges()
	for child in _contenedor_items.get_children():
		child.queue_free()
