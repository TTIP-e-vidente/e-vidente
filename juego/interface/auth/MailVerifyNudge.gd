extends CanvasLayer

signal verificar_ahora_solicitado()

const COLOR_TEXTO_OK := Color(0.18, 0.34, 0.26, 1)
const COLOR_TEXTO_ERROR := Color(0.72, 0.28, 0.22, 1)
const COLOR_TEXTO_BASE := Color(0.259, 0.471, 0.369, 1)

@onready var _label: Label = $PopupAnchor/PanelContainer/MarginContainer/HBoxContainer/LabelMensaje
@onready var _boton: Button = $PopupAnchor/PanelContainer/MarginContainer/HBoxContainer/BotonVerificar

var _aviso_temporal: String = ""
var _aviso_es_ok: bool = false


func _ready() -> void:
	_boton.pressed.connect(func(): verificar_ahora_solicitado.emit())
	visible = false


func _aplicar_color_mensaje(color: Color) -> void:
	_label.add_theme_color_override("font_color", color)
	_label.modulate = Color(1, 1, 1, 1)


func mostrar_aviso(texto: String, es_ok: bool = false) -> void:
	_aviso_temporal = texto.strip_edges()
	_aviso_es_ok = es_ok
	refrescar()


func refrescar() -> void:
	if not AuthApi.mail_pendiente_verificacion():
		visible = false
		_aviso_temporal = ""
		return
	var user: Dictionary = AuthApi.obtener_usuario_online()
	var mail: String = str(user.get("mail", "")).strip_edges()
	if mail.is_empty():
		visible = false
		return
	var verified_at: Variant = user.get("mail_verified_at", null)
	if AuthApi.mail_verified_at_valido(verified_at):
		visible = false
		_aviso_temporal = ""
		return
	var mensaje_base := (
		"Tu mail no está verificado. Verificalo ahora para activar avisos y recuperar tu cuenta."
	)
	if not _aviso_temporal.is_empty():
		_label.text = _aviso_temporal
		_aplicar_color_mensaje(COLOR_TEXTO_OK if _aviso_es_ok else COLOR_TEXTO_ERROR)
	else:
		_label.text = mensaje_base
		_aplicar_color_mensaje(COLOR_TEXTO_BASE)
	_boton.text = "Verificar ahora"
	visible = true
