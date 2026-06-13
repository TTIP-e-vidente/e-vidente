extends TextureButton

class_name ConceptoItem

signal seleccionado(item)

const CARD_SIZE := Vector2(300, 84)
const COLOR_TEXTO := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_TEXTO_BLOQUEADO := Color(1.0, 1.0, 1.0, 0.55)
const COLOR_TARJETA_NORMAL := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_TARJETA_HOVER := Color(1.05, 1.05, 1.05, 1.0)
const COLOR_TARJETA_SELECCIONADA := MiPaleta.ORO_CLARO
const COLOR_TARJETA_VINCULADA := MiPaleta.VERDE_BOSQUE
const COLOR_TARJETA_ERROR := MiPaleta.NARANJA_TIERRA
const COLOR_TARJETA_BLOQUEADA := Color(1.0, 1.0, 1.0, 0.62)

@onready var label: Label = $Label

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
var _base_scale := Vector2.ONE


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	_base_scale = scale
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_aplicar_estilo("normal")


func _on_pressed() -> void:
	if bloqueado:
		return
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


func configurar_desde_diccionario(datos: Dictionary, lado_item: String) -> void:
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


func reiniciar_estado() -> void:
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


func marcar_seleccionado() -> void:
	aplicar_estado_visual("seleccionada")


func marcar_correcto() -> void:
	marcar_error(false)


func marcar_incorrecto() -> void:
	marcar_error(true)


func restaurar_interaccion() -> void:
	bloqueado = false
	disabled = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_inside_tree() and is_instance_valid(label):
		label.modulate = COLOR_TEXTO


func bloquear_interaccion() -> void:
	bloqueado = true
	disabled = true
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
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.add_theme_constant_override("line_spacing", -2)
	label.add_theme_font_size_override("font_size", _calcular_tamano_fuente(texto))


func aplicar_estado_visual(tipo: String) -> void:
	if bloqueado and tipo != "disabled":
		return
	_estado_visual = tipo
	_aplicar_estilo(tipo)
	if tipo == "seleccionada":
		_animar_seleccion()


func animar_error() -> void:
	var base_position := position
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", base_position + Vector2(8, 0), 0.04)
	tween.tween_property(self, "position", base_position + Vector2(-8, 0), 0.06)
	tween.tween_property(self, "position", base_position, 0.05)


func _animar_seleccion() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _base_scale * 1.18, 0.10)
	tween.tween_property(self, "scale", _base_scale * 1.10, 0.10)


func _aplicar_estilo(tipo: String) -> void:
	var color_tarjeta := COLOR_TARJETA_NORMAL
	match tipo:
		"hover":
			color_tarjeta = COLOR_TARJETA_HOVER
		"seleccionada":
			color_tarjeta = COLOR_TARJETA_SELECCIONADA
		"vinculada":
			color_tarjeta = COLOR_TARJETA_VINCULADA
		"error":
			color_tarjeta = COLOR_TARJETA_ERROR
		"disabled":
			color_tarjeta = COLOR_TARJETA_BLOQUEADA
		_:
			color_tarjeta = COLOR_TARJETA_NORMAL
	self_modulate = color_tarjeta
	if is_instance_valid(label):
		label.modulate = COLOR_TEXTO_BLOQUEADO if tipo == "disabled" else COLOR_TEXTO
	if tipo == "seleccionada":
		scale = _base_scale * 1.10
	else:
		scale = _base_scale


func _calcular_tamano_fuente(texto_entrada: String) -> int:
	var largo := texto_entrada.length()
	if largo > 30:
		return 20
	if largo > 22:
		return 22
	if largo > 14:
		return 24
	if largo > 8:
		return 26
	return 28
