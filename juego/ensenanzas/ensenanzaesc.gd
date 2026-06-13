extends Control

signal continuar_presionado

const CONTINUAR_OFFSET_LEFT := 418.0
const CONTINUAR_OFFSET_TOP := 529.0
const CONTINUAR_OFFSET_RIGHT := 953.0
const CONTINUAR_OFFSET_BOTTOM := 787.0
const ESCALA_CONTINUAR := Vector2(0.6112045, 0.61994773)

@onready var titulo: Label = $LabelTitulo
@onready var texto: RichTextLabel = $RichTextLabel
@onready var imagen: TextureRect = $TextureRect
@onready var jugar: Label = $Jugar/Label
@onready var _boton_jugar: TextureButton = $Jugar


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_configurar_boton_continuar()
	if _boton_jugar != null and not _boton_jugar.pressed.is_connected(_on_jugar_presionado):
		_boton_jugar.pressed.connect(_on_jugar_presionado)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_configurar_boton_continuar()


func _configurar_boton_continuar() -> void:
	if _boton_jugar == null:
		return
	_boton_jugar.visible = true
	_boton_jugar.z_index = 20
	_boton_jugar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_boton_jugar.offset_left = CONTINUAR_OFFSET_LEFT
	_boton_jugar.offset_top = CONTINUAR_OFFSET_TOP
	_boton_jugar.offset_right = CONTINUAR_OFFSET_RIGHT
	_boton_jugar.offset_bottom = CONTINUAR_OFFSET_BOTTOM
	_boton_jugar.scale = ESCALA_CONTINUAR
	if jugar != null:
		jugar.text = "Continuar"


func mostrar_ensenanza(ensenanza: Ensenanza) -> void:
	titulo.text = ensenanza.titulo
	texto.text = ensenanza.texto
	_configurar_boton_continuar()
	if ensenanza.imagen.is_empty():
		imagen.texture = null
		return
	if ResourceLoader.exists(ensenanza.imagen):
		imagen.texture = load(ensenanza.imagen) as Texture2D
	else:
		push_warning("EnsenanzaEsc: imagen no encontrada: %s" % ensenanza.imagen)
		imagen.texture = null


func _on_jugar_presionado() -> void:
	# Diferir evita reentrancia con el cierre de CapaEnsenanzaEsc en el mismo frame.
	call_deferred("_emitir_continuar_presionado")


func _emitir_continuar_presionado() -> void:
	continuar_presionado.emit()
