extends CanvasLayer

signal verificacion_completada()
signal verificacion_omitida()

@onready var _line_edit_codigo: LineEdit = %LineEditCodigo
@onready var _boton_verificar: Button = %BotonVerificar
@onready var _boton_reenviar: Button = %BotonReenviar
@onready var _boton_omitir: Button = %BotonOmitir
@onready var _label_mensaje: Label = %LabelMensaje
@onready var _label_email: Label = %LabelEmail

var _is_loading := false
var _tiempo_cooldown := 0.0
var _requiere_verificacion := false


func _ready() -> void:
	_boton_verificar.pressed.connect(_on_verificar_presionado)
	_boton_reenviar.pressed.connect(_on_reenviar_presionado)
	_boton_omitir.pressed.connect(_on_omitir_presionado)
	_line_edit_codigo.text_submitted.connect(func(_texto: String) -> void: _on_verificar_presionado())

	_mostrar_email_usuario()
	_iniciar_cooldown(120.0)


func establecer_cooldown_inicial(segundos: float) -> void:
	_iniciar_cooldown(maxf(segundos, 0.0))


func configurar(requiere_verificacion: bool = false) -> void:
	_requiere_verificacion = requiere_verificacion
	_boton_omitir.visible = not _requiere_verificacion


func _process(delta: float) -> void:
	if _tiempo_cooldown > 0:
		_tiempo_cooldown -= delta
		if _tiempo_cooldown <= 0:
			_tiempo_cooldown = 0
			_boton_reenviar.disabled = false
			_boton_reenviar.text = "Reenviar código"
		else:
			_boton_reenviar.disabled = true
			_boton_reenviar.text = "Reenviar en %ds" % int(ceil(_tiempo_cooldown))


func _mostrar_email_usuario() -> void:
	var user := AuthApi.obtener_usuario_online()
	var mail := str(user.get("mail", ""))
	if not mail.is_empty():
		_label_email.text = mail
	else:
		_label_email.text = "tu casilla de correo"


func _on_verificar_presionado() -> void:
	if _is_loading:
		return

	var codigo := _line_edit_codigo.text.strip_edges()
	if codigo.length() != 6 or not codigo.is_valid_int():
		_mostrar_mensaje("El código debe tener 6 números.", false)
		return

	_establecer_cargando(true)
	_mostrar_mensaje("Verificando...", true)

	var res := await AuthApi.confirmar_codigo_verificacion(codigo)
	_establecer_cargando(false)

	if res.get("ok", false):
		_mostrar_mensaje("¡Correo verificado con éxito!", true)
		await get_tree().create_timer(1.0).timeout
		verificacion_completada.emit()
	else:
		_mostrar_mensaje(
			AuthApi.mensaje_verificacion(res, "Código incorrecto o expirado."),
			false
		)


func _on_reenviar_presionado() -> void:
	if _is_loading or _tiempo_cooldown > 0:
		return

	_establecer_cargando(true)
	_mostrar_mensaje("Solicitando nuevo código...", true)

	var res := await AuthApi.solicitar_codigo_verificacion()
	_establecer_cargando(false)

	if res.get("ok", false):
		_mostrar_mensaje("¡Código reenviado! Revisá tu correo.", true)
		_iniciar_cooldown(float(AuthApi.cooldown_verificacion(res, 120)))
	else:
		var cooldown := AuthApi.cooldown_verificacion(res, 0)
		if cooldown > 0:
			_iniciar_cooldown(float(cooldown))
		_mostrar_mensaje(
			AuthApi.mensaje_verificacion(res, "No se pudo reenviar. Esperá e intentá nuevamente."),
			false
		)


func _on_omitir_presionado() -> void:
	if _is_loading or _requiere_verificacion:
		return
	verificacion_omitida.emit()


func _iniciar_cooldown(segundos: float) -> void:
	_tiempo_cooldown = maxf(segundos, 0.0)
	_boton_reenviar.disabled = _tiempo_cooldown > 0.0


func _establecer_cargando(cargando: bool) -> void:
	_is_loading = cargando
	_boton_verificar.disabled = cargando
	_boton_omitir.disabled = cargando or _requiere_verificacion
	_line_edit_codigo.editable = not cargando


func _mostrar_mensaje(texto: String, es_info: bool) -> void:
	_label_mensaje.text = texto
	if es_info:
		_label_mensaje.modulate = Color(0.8, 0.9, 0.8, 1.0)
	else:
		_label_mensaje.modulate = Color(0.9, 0.4, 0.4, 1.0)
