extends TextureButton

class_name ConceptoItem

signal seleccionado(item)

const CAJA_TEXTO_POSICION := Vector2(-150, -41)
const CAJA_TEXTO_TAMANO := Vector2(300, 82)

@onready var label: Label = $Label

var par_id := -1
var lado := "" 
var bloqueado := false


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if bloqueado:
		return

	seleccionado.emit(self)


func ajustar_titulo(texto: String) -> void:
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
