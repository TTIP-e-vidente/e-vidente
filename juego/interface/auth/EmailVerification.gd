extends Control

signal verificacion_completada()
signal verificacion_omitida()

const FlowHelper := preload("res://interface/auth/EmailVerificationFlowHelper.gd")
const RUBIK_FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"
const FLECHA_ATRAS := preload(
	"res://assets-sistema/interfaz/flecha-ir-para-atras-historias.png"
)


@onready var _panel_central: PanelContainer = (
	$MarginRoot/VBoxRoot/CenterContainer/PanelCentral
)
@onready var _label_titulo: Label = (
	$MarginRoot/VBoxRoot/CenterContainer/PanelCentral/MarginContainer/VBoxContainer/Titulo
)
@onready var _line_edit_codigo: LineEdit = %LineEditCodigo
@onready var _boton_verificar: Button = %BotonVerificar
@onready var _boton_reenviar: Button = %BotonReenviar
@onready var _boton_omitir: Button = %BotonOmitir
@onready var _boton_ayuda_mail: Button = %BotonAyudaMail
@onready var _boton_volver: Button = %BotonVolver
@onready var _label_ayuda_mail: Label = %LabelAyudaMail

const AYUDA_MAIL_TEXTO := (
	"• Buscá un mail con asunto «Código E-VIDENTE: ######» (no el de bienvenida).\n"
	+ "• Copiá los 6 números del asunto o del bloque dorado del mail.\n"
	+ "• Pegá en el juego: no hace falta agregar espacios.\n"
	+ "• No uses el botón «Copiar código» si abre una página rara: seleccioná el número manualmente.\n"
	+ "• Revisá spam o promociones.\n"
	+ "• Puede tardar 1–2 minutos.\n"
	+ "• Usá «Reenviar código» si pasaron más de 2 minutos.\n"
	+ "• El mail de bienvenida llega recién después de verificar.\n"
	+ "• En desarrollo sin Brevo: el código aparece en la consola del backend."
)
@onready var _label_mensaje: Label = %LabelMensaje
@onready var _label_email: Label = %LabelEmail

var _is_loading := false
var _tiempo_cooldown := 0.0
var _requiere_verificacion := false
var _salida_en_curso := false


func _ready() -> void:
	_boton_verificar.pressed.connect(_on_verificar_presionado)
	_boton_reenviar.pressed.connect(_on_reenviar_presionado)
	_boton_omitir.pressed.connect(_on_omitir_presionado)
	_boton_ayuda_mail.pressed.connect(_on_ayuda_mail_presionado)
	_boton_volver.pressed.connect(_on_volver_presionado)
	_line_edit_codigo.text_submitted.connect(func(_texto: String) -> void: _on_verificar_presionado())
	_line_edit_codigo.text_changed.connect(_on_codigo_text_changed)

	_label_ayuda_mail.visible = false
	_aplicar_estilos()
	_configurar_boton_volver()
	_aplicar_configuracion_desde_meta()
	_mostrar_email_usuario()
	call_deferred("_enfocar_codigo")
	call_deferred("_sincronizar_estado_desde_servidor")


func _aplicar_configuracion_desde_meta() -> void:
	var root := get_tree().root
	_requiere_verificacion = bool(root.get_meta(FlowHelper.META_OBLIGATORIO, false))
	configurar(_requiere_verificacion)

	var evaluacion: Variant = root.get_meta(FlowHelper.META_EVALUACION, {})
	if evaluacion is Dictionary:
		var ev := evaluacion as Dictionary
		var cooldown := float(ev.get("cooldown_seconds", 0.0))
		if cooldown > 0.0:
			establecer_cooldown_inicial(cooldown)
		var feedback := str(ev.get("feedback", ""))
		if not feedback.is_empty():
			establecer_mensaje_inicial(feedback, bool(ev.get("feedback_ok", true)))
		elif ev.is_empty():
			establecer_mensaje_inicial(
				"Ingresá el código de 6 dígitos que te enviamos por mail.",
				true
			)


func _sincronizar_estado_desde_servidor() -> void:
	if not AuthApi.esta_logueado():
		return
	var res := await AuthApi.obtener_estado_verificacion_email()
	if not res.get("ok", false):
		return
	var data: Variant = res.get("data", {})
	if not data is Dictionary:
		return
	var verification: Variant = (data as Dictionary).get("verification", {})
	if not verification is Dictionary:
		return
	var v := verification as Dictionary
	var cooldown := int(v.get("cooldown_seconds", 0))
	if cooldown > 0:
		_iniciar_cooldown(float(cooldown))
	if v.get("attempts_remaining") != null:
		var remaining := int(v.get("attempts_remaining", 0))
		var max_attempts := int(v.get("max_attempts", 5))
		if remaining >= 0 and remaining < max_attempts:
			_mostrar_mensaje("Te quedan %d intento(s) para este código." % remaining, true)
	var delivery: Variant = v.get("last_verification_delivery", null)
	if delivery is Dictionary:
		var status := str((delivery as Dictionary).get("status", ""))
		if status == "failed":
			var err := str((delivery as Dictionary).get("error_message", "")).strip_edges()
			var msg := "El último envío del código falló. Usá «Reenviar código»."
			if not err.is_empty():
				msg += " (%s)" % err
			_mostrar_mensaje(msg, false)


func _enfocar_codigo() -> void:
	if is_instance_valid(_line_edit_codigo):
		_line_edit_codigo.grab_focus()


func establecer_mensaje_inicial(texto: String, es_info: bool = true) -> void:
	_mostrar_mensaje(texto, es_info)


func establecer_cooldown_inicial(segundos: float) -> void:
	_iniciar_cooldown(maxf(segundos, 0.0))


func configurar(requiere_verificacion: bool = false) -> void:
	_requiere_verificacion = requiere_verificacion
	_boton_omitir.visible = not _requiere_verificacion
	_boton_volver.visible = not _requiere_verificacion
	if _requiere_verificacion:
		_boton_omitir.disabled = true
		_boton_volver.disabled = true
	else:
		_configurar_boton_volver()


func _configurar_boton_volver() -> void:
	if not is_instance_valid(_boton_volver):
		return
	_boton_volver.text = ""
	_boton_volver.tooltip_text = "Volver"
	_boton_volver.icon = FLECHA_ATRAS
	_boton_volver.flat = true
	_boton_volver.expand_icon = true
	_boton_volver.custom_minimum_size = Vector2(72, 72)


func _aplicar_estilos() -> void:
	var rubik: Font = load(RUBIK_FONT_PATH) as Font

	if is_instance_valid(_panel_central):
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.995, 0.992, 0.985, 1)
		panel.set_corner_radius_all(20)
		panel.shadow_color = Color(0, 0, 0, 0.12)
		panel.shadow_size = 10
		panel.shadow_offset = Vector2(0, 4)
		_panel_central.add_theme_stylebox_override("panel", panel)

	if is_instance_valid(_label_titulo):
		_label_titulo.add_theme_color_override("font_color", MiPaleta.VERDE_BOSQUE)
		if rubik != null:
			_label_titulo.add_theme_font_override("font", rubik)

	if is_instance_valid(_label_email):
		_label_email.add_theme_color_override("font_color", Color(0.2, 0.35, 0.28, 1))
		if rubik != null:
			_label_email.add_theme_font_override("font", rubik)

	if is_instance_valid(_line_edit_codigo):
		var input_bg := StyleBoxFlat.new()
		input_bg.bg_color = Color(0.975, 0.972, 0.96, 1)
		input_bg.border_color = Color(MiPaleta.ORO_CLARO.r, MiPaleta.ORO_CLARO.g, MiPaleta.ORO_CLARO.b, 0.85)
		input_bg.set_border_width_all(2)
		input_bg.set_corner_radius_all(12)
		_line_edit_codigo.add_theme_stylebox_override("normal", input_bg)
		_line_edit_codigo.add_theme_stylebox_override("focus", input_bg)
		_line_edit_codigo.add_theme_color_override("font_color", Color(0.14, 0.13, 0.09, 1))
		if rubik != null:
			_line_edit_codigo.add_theme_font_override("font", rubik)

	if is_instance_valid(_boton_verificar):
		var btn := StyleBoxFlat.new()
		btn.bg_color = MiPaleta.VERDE_BOSQUE
		btn.set_corner_radius_all(12)
		btn.content_margin_top = 10
		btn.content_margin_bottom = 10
		_boton_verificar.add_theme_stylebox_override("normal", btn)
		_boton_verificar.add_theme_stylebox_override("hover", btn)
		_boton_verificar.add_theme_color_override("font_color", Color.WHITE)
		if rubik != null:
			_boton_verificar.add_theme_font_override("font", rubik)

	for lbl: Label in [_label_mensaje, _label_ayuda_mail]:
		if is_instance_valid(lbl) and rubik != null:
			lbl.add_theme_font_override("font", rubik)


func _on_ayuda_mail_presionado() -> void:
	if not is_instance_valid(_label_ayuda_mail):
		return
	_label_ayuda_mail.visible = not _label_ayuda_mail.visible
	if _label_ayuda_mail.visible:
		_label_ayuda_mail.text = AYUDA_MAIL_TEXTO


func _on_volver_presionado() -> void:
	if _is_loading or _requiere_verificacion or _salida_en_curso:
		return
	_salir_con_outcome("omitido")


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


func _on_codigo_text_changed(new_text: String) -> void:
	var digits := _extraer_digitos_codigo(new_text)
	if digits != new_text:
		_line_edit_codigo.text = digits
		_line_edit_codigo.caret_position = digits.length()


static func _extraer_digitos_codigo(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		if ch >= "0" and ch <= "9":
			out += ch
		if out.length() >= 6:
			break
	return out


func _on_verificar_presionado() -> void:
	if _is_loading or _salida_en_curso:
		return

	var codigo := _extraer_digitos_codigo(_line_edit_codigo.text)
	if codigo.length() != 6:
		_mostrar_mensaje("El código debe tener 6 números (sin espacios).", false)
		return

	_establecer_cargando(true)
	_mostrar_mensaje("Verificando...", true)

	var res := await AuthApi.confirmar_codigo_verificacion(codigo)
	_establecer_cargando(false)

	if res.get("ok", false):
		_mostrar_mensaje("¡Mail verificado! Ahora te enviamos el mail de bienvenida.", true)
		await get_tree().create_timer(0.8).timeout
		verificacion_completada.emit()
		await _salir_con_outcome("completado")
	else:
		_mostrar_mensaje(
			AuthApi.mensaje_verificacion(res, "Código incorrecto o expirado."),
			false
		)


func _on_reenviar_presionado() -> void:
	if _is_loading or _tiempo_cooldown > 0 or _salida_en_curso:
		return

	_establecer_cargando(true)
	_mostrar_mensaje("Solicitando nuevo código...", true)

	var res := await AuthApi.solicitar_codigo_verificacion()
	_establecer_cargando(false)

	var evaluacion := AuthApi.evaluar_respuesta_verificacion(res)
	var cooldown := int(evaluacion.get("cooldown_seconds", 0))
	if bool(res.get("ok", false)) and cooldown <= 0:
		cooldown = AuthApi.cooldown_verificacion(res, 120)
	if cooldown > 0:
		_iniciar_cooldown(float(cooldown))
	if not str(evaluacion.get("feedback", "")).is_empty():
		_mostrar_mensaje(str(evaluacion.get("feedback", "")), bool(evaluacion.get("feedback_ok", false)))
	elif not res.get("ok", false):
		_mostrar_mensaje(
			AuthApi.mensaje_verificacion(res, "No se pudo reenviar. Esperá e intentá nuevamente."),
			false
		)


func _on_omitir_presionado() -> void:
	if _is_loading or _requiere_verificacion or _salida_en_curso:
		return
	verificacion_omitida.emit()
	await _salir_con_outcome("omitido")


func _salir_con_outcome(outcome: String) -> void:
	if _salida_en_curso:
		return
	_salida_en_curso = true

	var root := get_tree().root
	root.set_meta(FlowHelper.META_OUTCOME, outcome)
	FlowHelper.complete_waiter(outcome)

	var return_scene := str(
		root.get_meta(FlowHelper.META_RETURN_SCENE, GameSceneRouter.MAIN_MENU_SCENE_PATH)
	).strip_edges()
	if return_scene.is_empty():
		return_scene = GameSceneRouter.MAIN_MENU_SCENE_PATH

	FlowHelper.limpiar_metas_config(root)
	await TransicionEscenas.cambiar_escena_normal(return_scene)


func _iniciar_cooldown(segundos: float) -> void:
	_tiempo_cooldown = maxf(segundos, 0.0)
	_boton_reenviar.disabled = _tiempo_cooldown > 0.0
	if _tiempo_cooldown <= 0.0:
		_boton_reenviar.text = "Reenviar código"


func _establecer_cargando(cargando: bool) -> void:
	_is_loading = cargando
	_boton_verificar.disabled = cargando
	_boton_omitir.disabled = cargando or _requiere_verificacion
	_boton_volver.disabled = cargando or _requiere_verificacion
	_line_edit_codigo.editable = not cargando


func _mostrar_mensaje(texto: String, es_info: bool) -> void:
	_label_mensaje.text = texto
	if es_info:
		_label_mensaje.modulate = MiPaleta.FEEDBACK_OK
	else:
		_label_mensaje.modulate = MiPaleta.FEEDBACK_ERROR
