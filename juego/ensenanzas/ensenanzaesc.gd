extends Control

@onready var titulo = $LabelTitulo
@onready var texto = $RichTextLabel
@onready var imagen = $TextureRect
@onready var jugar: Label = $Jugar/Label

func _ready() -> void:
	jugar.text = "Continuar"

func mostrar_ensenanza(ensenanza: Ensenanza):
	titulo.text = ensenanza.titulo
	texto.text = ensenanza.texto
	imagen.texture = load(ensenanza.imagen)
