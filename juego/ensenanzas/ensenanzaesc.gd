extends Control

signal continuar_presionado

@onready var titulo: Label = $LabelTitulo
@onready var texto: RichTextLabel = $RichTextLabel
@onready var imagen: TextureRect = $TextureRect
@onready var jugar: Label = $Jugar/Label
@onready var _boton_jugar: TextureButton = $Jugar


func _ready() -> void:
	jugar.text = "Continuar"
	if _boton_jugar != null and not _boton_jugar.pressed.is_connected(_on_jugar_presionado):
		_boton_jugar.pressed.connect(_on_jugar_presionado)


func mostrar_ensenanza(ensenanza: Ensenanza) -> void:
	titulo.text = ensenanza.titulo
	texto.text = ensenanza.texto
	if ensenanza.imagen.is_empty():
		imagen.texture = null
		return
	if ResourceLoader.exists(ensenanza.imagen):
		imagen.texture = load(ensenanza.imagen) as Texture2D
	else:
		push_warning("EnsenanzaEsc: imagen no encontrada: %s" % ensenanza.imagen)
		imagen.texture = null


func _on_jugar_presionado() -> void:
	continuar_presionado.emit()
