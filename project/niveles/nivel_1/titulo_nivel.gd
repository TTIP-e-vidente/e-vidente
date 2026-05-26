extends Sprite2D

@onready var titulo_nivel: Label = $Label
@onready var titulo_s: Sprite2D = $"."

func ajustar_titulo(texto: String) -> void:
	titulo_nivel.text = texto

	var largo := texto.length()
	var font_size := 40

	if largo > 20:
		font_size = 20
	elif largo > 15:
		font_size = 25
	elif largo > 10:
		font_size = 32

	titulo_nivel.add_theme_font_size_override("font_size", font_size)
