extends TextureButton

class_name ConceptoItem

signal seleccionado(item)
@onready var label: Label = $Label

var par_id := -1
var lado := "" 
var bloqueado := false


func _ready():
	pressed.connect(_on_pressed)


func _on_pressed():

	if bloqueado:
		return

	seleccionado.emit(self)
	
func ajustar_titulo(texto: String) -> void:
	label.text = texto

	var largo := texto.length()
	var font_size := 40

	if largo > 20:
		font_size = 20
	elif largo > 15:
		font_size = 25
	elif largo > 10:
		font_size = 32

	label.add_theme_font_size_override("font_size", font_size)
