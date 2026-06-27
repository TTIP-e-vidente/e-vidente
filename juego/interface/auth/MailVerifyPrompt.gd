extends CanvasLayer

signal verificar_solicitado()
signal pospuesto()


var _label_mensaje: Label
var _boton_despues: Button
var _boton_verificar: Button


func _ready() -> void:
	layer = 25
	visible = false
	var root: VBoxContainer = (
		$PanelWrapper/PanelContainer/MarginContainer/VBoxContainer as VBoxContainer
	)
	_label_mensaje = root.get_node("LabelMensaje") as Label
	var botones: HBoxContainer = root.get_node("Botones") as HBoxContainer
	_boton_despues = botones.get_node("BotonDespues") as Button
	_boton_verificar = botones.get_node("BotonVerificar") as Button
	_boton_despues.pressed.connect(_on_despues_presionado)
	_boton_verificar.pressed.connect(_on_verificar_presionado)


func mostrar() -> void:
	if not AuthApi.esta_logueado() or not AuthApi.mail_pendiente_verificacion():
		visible = false
		return
	_label_mensaje.text = (
		"Tu mail todavía no está verificado.\n"
		+ "Podés recibir un código de 6 dígitos para confirmarlo."
	)
	visible = true


func ocultar() -> void:
	visible = false


func _on_despues_presionado() -> void:
	ocultar()
	pospuesto.emit()


func _on_verificar_presionado() -> void:
	ocultar()
	verificar_solicitado.emit()
