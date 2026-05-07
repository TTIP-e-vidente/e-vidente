extends TextureButton

class_name ConceptoItem

signal seleccionado(item)

const CAJA_TEXTO_POSICION := Vector2(-150, -41)
const CAJA_TEXTO_TAMANO := Vector2(300, 82)

@onready var label: Label = $Label

var concept_id := ""
var texto := ""
var lado := ""
var par_key := ""
var vinculada_con: ConceptoItem = null
var tiene_error := false
var animar_vinculo := false
var bloqueado := false


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if bloqueado:
		return

	seleccionado.emit(self)


func configurar(id: String, texto_item: String, lado_item: String, clave_par: String) -> void:
	concept_id = id
	texto = texto_item
	lado = lado_item
	par_key = clave_par
	limpiar_vinculo()
	restaurar_interaccion()
	show()
	_actualizar_texto()


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


func vincular_con(item_derecha: ConceptoItem) -> void:
	vinculada_con = item_derecha
	tiene_error = false
	animar_vinculo = true


func marcar_error(hay_error: bool) -> void:
	tiene_error = hay_error


func restaurar_interaccion() -> void:
	bloqueado = false
	disabled = false


func bloquear_interaccion() -> void:
	bloqueado = true
	disabled = true


func es_izquierda() -> bool:
	return lado == "izquierda"


func es_derecha() -> bool:
	return lado == "derecha"


func esta_vinculada() -> bool:
	return vinculada_con != null


func es_correcta() -> bool:
	return vinculada_con != null and par_key == vinculada_con.par_key


func _actualizar_texto() -> void:
	label.text = texto
	label.position = CAJA_TEXTO_POSICION
	label.size = CAJA_TEXTO_TAMANO
	label.pivot_offset = CAJA_TEXTO_TAMANO * 0.5
	label.scale = Vector2.ONE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_constant_override("line_spacing", -2)
	label.add_theme_font_size_override("font_size", _calcular_tamano_fuente(texto))


func _calcular_tamano_fuente(texto: String) -> int:
	var largo := texto.length()
	if largo > 30:
		return 20
	if largo > 24:
		return 22
	if largo > 17:
		return 26
	if largo > 10:
		return 32
	return 38
