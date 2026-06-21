extends CanvasLayer

signal verificar_ahora_solicitado()

@onready var _panel: PanelContainer = $PanelContainer
@onready var _label: Label = $PanelContainer/MarginContainer/HBoxContainer/LabelMensaje
@onready var _boton: Button = $PanelContainer/MarginContainer/HBoxContainer/BotonVerificar


func _ready() -> void:
	layer = 5
	_boton.pressed.connect(func(): verificar_ahora_solicitado.emit())
	visible = false


func refrescar() -> void:
	if not AuthApi.esta_logueado():
		visible = false
		return
	var user := AuthApi.obtener_usuario_online()
	var mail := str(user.get("mail", "")).strip_edges()
	if mail.is_empty():
		mail = SaveManager.obtener_email_usuario_actual()
	if mail.is_empty():
		visible = false
		return
	var verified_at := str(user.get("mail_verified_at", "")).strip_edges()
	if not verified_at.is_empty():
		visible = false
		return
	_label.text = "Verificá tu mail para activar avisos y recuperar tu cuenta."
	_boton.text = "Verificar ahora"
	visible = true
