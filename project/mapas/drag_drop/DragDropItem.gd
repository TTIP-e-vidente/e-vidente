extends PanelContainer
class_name DragDropItem

var datos_item: Dictionary = {}

var _etiqueta_item: Label
var _imagen_item: TextureRect


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
	var vista_previa: Control = duplicate() as Control
	if vista_previa == null:
		return
	vista_previa.modulate = Color(1, 1, 1, 0.75)
	set_drag_preview(vista_previa)


func _construir_ui() -> void:
	if _etiqueta_item != null and _imagen_item != null:
		return

	var contenedor_margen: MarginContainer = MarginContainer.new()
	contenedor_margen.add_theme_constant_override("margin_left", 12)
	contenedor_margen.add_theme_constant_override("margin_top", 12)
	contenedor_margen.add_theme_constant_override("margin_right", 12)
	contenedor_margen.add_theme_constant_override("margin_bottom", 12)
	add_child(contenedor_margen)

	var contenedor_vertical: VBoxContainer = VBoxContainer.new()
	contenedor_vertical.alignment = BoxContainer.ALIGNMENT_CENTER
	contenedor_vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor_margen.add_child(contenedor_vertical)

	_imagen_item = TextureRect.new()
	_imagen_item.custom_minimum_size = Vector2(72, 72)
	_imagen_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_imagen_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor_vertical.add_child(_imagen_item)

	_etiqueta_item = Label.new()
	_etiqueta_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etiqueta_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor_vertical.add_child(_etiqueta_item)


func _renderizar() -> void:
	if _etiqueta_item == null or _imagen_item == null:
		return

	var ruta_imagen: String = str(datos_item.get("image", "")).strip_edges()
	var textura: Texture2D = load(ruta_imagen) as Texture2D if not ruta_imagen.is_empty() else null
	_imagen_item.texture = textura
	_imagen_item.visible = textura != null
	_etiqueta_item.text = str(datos_item.get("label", "Item")).strip_edges()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
