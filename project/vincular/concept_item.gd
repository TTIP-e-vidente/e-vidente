extends PanelContainer

class_name ConceptoItem

signal seleccionado(item)

const CARD_SIZE := Vector2(260, 78)
const COLOR_TEXTO := Color(0.95, 0.95, 0.93, 1.0)
const COLOR_TEXTO_BLOQUEADO := Color(0.95, 0.95, 0.93, 0.58)
const ESTILOS := {
	"normal": {
		"bg": Color(0.11, 0.11, 0.1, 0.98),
		"border": Color(0.04, 0.04, 0.035, 1.0),
		"width": 3,
	},
	"hover": {
		"bg": Color(0.15, 0.15, 0.13, 0.98),
		"border": Color(0.83, 0.74, 0.42, 1.0),
		"width": 4,
	},
	"seleccionada": {
		"bg": Color(0.18, 0.15, 0.11, 0.98),
		"border": Color(0.95, 0.58, 0.18, 1.0),
		"width": 5,
	},
	"vinculada": {
		"bg": Color(0.12, 0.16, 0.13, 0.98),
		"border": Color(0.38, 0.68, 0.45, 1.0),
		"width": 4,
	},
	"error": {
		"bg": Color(0.22, 0.12, 0.12, 0.98),
		"border": Color(0.9, 0.28, 0.24, 1.0),
		"width": 5,
	},
	"disabled": {
		"bg": Color(0.1, 0.1, 0.095, 0.62),
		"border": Color(0.04, 0.04, 0.035, 0.72),
		"width": 2,
	},
}

@onready var label: Label = $Padding/Content/Label
@onready var status_mark: Label = $Padding/Content/StatusMark

var concept_id := ""
var texto := ""
var lado := ""
var par_key := ""
var vinculada_con: ConceptoItem = null
var tiene_error := false
var animar_vinculo := false
var bloqueado := false
var _estado_visual := "normal"
var _hover := false


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_aplicar_estilo("normal")


func _on_gui_input(event: InputEvent) -> void:
	if bloqueado:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		seleccionado.emit(self)
	if event.is_action_pressed("ui_accept"):
		seleccionado.emit(self)


func _on_mouse_entered() -> void:
	_hover = true
	if _estado_visual == "normal":
		_aplicar_estilo("hover")


func _on_mouse_exited() -> void:
	_hover = false
	if _estado_visual == "normal":
		_aplicar_estilo("normal")


func configurar(id: String, texto_item: String, lado_item: String, clave_par: String) -> void:
	concept_id = id
	texto = texto_item
	lado = lado_item
	par_key = clave_par
	limpiar_vinculo()
	restaurar_interaccion()
	aplicar_estado_visual("normal")
	show()
	_actualizar_texto()


func setup(datos: Dictionary, lado_item: String) -> void:
	configurar(
		str(datos.get("id", "")).strip_edges(),
		str(datos.get("texto", datos.get("text", ""))).strip_edges(),
		lado_item,
		str(datos.get("id_par", datos.get("par_key", ""))).strip_edges()
	)


func ocultar_y_bloquear() -> void:
	concept_id = ""
	texto = ""
	lado = ""
	par_key = ""
	limpiar_vinculo()
	bloquear_interaccion()
	hide()


func limpiar_vinculo() -> void:
	vinculada_con = null
	tiene_error = false
	animar_vinculo = false
	if is_inside_tree() and not bloqueado:
		aplicar_estado_visual("normal")


func reset_state() -> void:
	limpiar_vinculo()


func vincular_con(item_derecha: ConceptoItem) -> void:
	vinculada_con = item_derecha
	tiene_error = false
	animar_vinculo = true


func marcar_error(hay_error: bool) -> void:
	tiene_error = hay_error
	if hay_error:
		aplicar_estado_visual("error")
		animar_error()
	else:
		aplicar_estado_visual("vinculada")


func set_selected() -> void:
	aplicar_estado_visual("seleccionada")


func set_correct() -> void:
	marcar_error(false)


func set_wrong() -> void:
	marcar_error(true)


func set_disabled() -> void:
	bloquear_interaccion()


func restaurar_interaccion() -> void:
	bloqueado = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE
	if is_inside_tree():
		label.modulate = COLOR_TEXTO


func bloquear_interaccion() -> void:
	bloqueado = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	aplicar_estado_visual("disabled")


func es_izquierda() -> bool:
	return lado == "izquierda"


func es_derecha() -> bool:
	return lado == "derecha"


func esta_vinculada() -> bool:
	return vinculada_con != null


func es_correcta() -> bool:
	# Compatibilidad legacy; la escena principal decide la validacion.
	return vinculada_con != null and par_key == vinculada_con.par_key


func _actualizar_texto() -> void:
	label.text = texto
	label.scale = Vector2.ONE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_constant_override("line_spacing", -2)
	label.add_theme_font_size_override("font_size", _calcular_tamano_fuente(texto))


func aplicar_estado_visual(tipo: String) -> void:
	if bloqueado and tipo != "disabled":
		return
	_estado_visual = tipo
	_aplicar_estilo(tipo)
	match tipo:
		"seleccionada":
			status_mark.text = ">"
			_animar_seleccion()
		"vinculada":
			status_mark.text = "OK"
		"error":
			status_mark.text = "X"
		"disabled":
			status_mark.text = ""
			scale = Vector2.ONE
		_:
			status_mark.text = ""
			scale = Vector2.ONE


func animar_error() -> void:
	var base_position := position
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", base_position + Vector2(8, 0), 0.04)
	tween.tween_property(self, "position", base_position + Vector2(-8, 0), 0.06)
	tween.tween_property(self, "position", base_position, 0.05)


func _animar_seleccion() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.08)


func _aplicar_estilo(tipo: String) -> void:
	var datos: Dictionary = ESTILOS.get(tipo, ESTILOS["normal"])
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = datos["bg"]
	estilo.border_color = datos["border"]
	var ancho := int(datos["width"])
	estilo.border_width_left = ancho
	estilo.border_width_top = ancho
	estilo.border_width_right = ancho
	estilo.border_width_bottom = ancho
	estilo.corner_radius_top_left = 8
	estilo.corner_radius_top_right = 8
	estilo.corner_radius_bottom_right = 8
	estilo.corner_radius_bottom_left = 8
	estilo.content_margin_left = 0
	estilo.content_margin_top = 0
	estilo.content_margin_right = 0
	estilo.content_margin_bottom = 0
	add_theme_stylebox_override("panel", estilo)
	if is_instance_valid(label):
		label.modulate = COLOR_TEXTO_BLOQUEADO if tipo == "disabled" else COLOR_TEXTO
	if is_instance_valid(status_mark):
		status_mark.modulate = COLOR_TEXTO_BLOQUEADO if tipo == "disabled" else COLOR_TEXTO


func _calcular_tamano_fuente(texto: String) -> int:
	var largo := texto.length()
	if largo > 30:
		return 18
	if largo > 24:
		return 20
	if largo > 17:
		return 23
	if largo > 10:
		return 27
	return 30
