
extends CanvasLayer
class_name FinalizacionDeNodo

const OVERLAY_LAYER := 69  

var _datos: Dictionary = {}
var _continuar_btn: Button = null


func _init() -> void:
	layer = OVERLAY_LAYER


func configurar(datos: Dictionary) -> void:
	_datos = datos.duplicate(true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_construir_ui()
	if _continuar_btn != null:
		_continuar_btn.grab_focus()


func _construir_ui() -> void:
	# Fondo semitransparente
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.05, 0.1, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# Centrar tarjeta
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)

	# Tarjeta contenedora
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(340.0, 0.0)
	center.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# --- Titulo del nodo ---
	var titulo_nodo: String = str(_datos.get("titulo_nodo", "")).strip_edges()
	if not titulo_nodo.is_empty():
		var titulo_label := Label.new()
		titulo_label.text = titulo_nodo
		titulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo_label.add_theme_font_size_override("font_size", 18)
		titulo_label.modulate = Color(0.9, 0.9, 0.9, 1.0)
		vbox.add_child(titulo_label)

	# --- Encabezado ¡Completado! ---
	var heading := Label.new()
	heading.text = "¡Nodo completado!"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	heading.modulate = Color(0.4, 1.0, 0.5, 1.0)
	vbox.add_child(heading)

	# --- Separador ---
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# --- EXP ganada ---
	var exp_ganada: int = int(_datos.get("exp_ganada", 0))
	var exp_label := Label.new()
	exp_label.text = "+%d EXP" % exp_ganada
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.add_theme_font_size_override("font_size", 32)
	exp_label.modulate = Color(1.0, 0.88, 0.2, 1.0)
	vbox.add_child(exp_label)

	# --- Total acumulado ---
	var total_exp: int = int(_datos.get("total_exp", 0))
	var total_label := Label.new()
	total_label.text = "Total: %d EXP" % total_exp
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 16)
	total_label.modulate = Color(0.75, 0.75, 0.75, 1.0)
	vbox.add_child(total_label)

	# --- Separador ---
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# --- Botón Continuar ---
	_continuar_btn = Button.new()
	_continuar_btn.text = "Continuar"
	_continuar_btn.custom_minimum_size = Vector2(160.0, 44.0)
	_continuar_btn.pressed.connect(_al_continuar)
	vbox.add_child(_continuar_btn)


func _exit_tree() -> void:
	# Garantiza que el árbol se despausa si el overlay se elimina sin presionar Continuar.
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false


func _al_continuar() -> void:
	get_tree().paused = false
	queue_free()
