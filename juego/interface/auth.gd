extends Control

const ARCHIVERO_SCENE := "res://niveles/selector.tscn"
const INTRO_SCENE := "res://niveles/intro.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)
const ProfileMailSyncHelperScript := preload(
	"res://interface/auth/ProfileMailSyncHelper.gd"
)

var profile_name_preview_label: Label
var profile_email_preview_label: Label
var profile_age_preview_label: Label
var summary_save_label: Label
var avatar_placeholder_label: Label
var username_input: LineEdit
var birth_date_input: LineEdit
var email_input: LineEdit
var avatar_path_input: LineEdit
var choose_avatar_button: Button
var clear_avatar_button: Button
var feedback_label: Label
var avatar_preview: TextureRect
var back_button: Button
var avatar_dialog: FileDialog
var _age_display_label: Label
var _email_notifications_checkbox: CheckBox
var _email_notifications_hint_label: Label
var _mail_verify_status_label: Label
var _mail_verify_hint_label: Label
var _button_verify_email: Button
var _perfil_online_sucio := false

func _ready() -> void:
	_cachear_nodos_ui()
	_configurar_ui_estatica()
	username_input.text_changed.connect(_refrescar_vista_previa_desde_formulario)
	username_input.text_changed.connect(_marcar_perfil_online_sucio)
	birth_date_input.text_changed.connect(_refrescar_vista_previa_desde_formulario)
	birth_date_input.text_changed.connect(_marcar_perfil_online_sucio)
	email_input.text_changed.connect(_refrescar_vista_previa_desde_formulario)
	email_input.text_changed.connect(_marcar_perfil_online_sucio)
	email_input.text_changed.connect(_on_email_input_cambiado)
	username_input.focus_exited.connect(_intentar_autosave)
	birth_date_input.focus_exited.connect(_intentar_autosave)
	email_input.focus_exited.connect(_intentar_autosave)
	if is_instance_valid(_email_notifications_checkbox):
		_email_notifications_checkbox.toggled.connect(_on_notificaciones_mail_cambiadas)
	_cargar_estado_perfil_actual()
	_establecer_feedback("Los cambios se guardan automáticamente.", true)
	BackendSession.session_expired.connect(_on_sesion_expirada)
	call_deferred("_sincronizar_verificacion_mail_desde_servidor")
	call_deferred("_procesar_retorno_verificacion_mail")


func _on_sesion_expirada() -> void:
	_establecer_feedback("Sesión expirada. Los cambios se guardan localmente.", false)


func _cachear_nodos_ui() -> void:
	back_button = $BackButton as Button
	avatar_dialog = $AvatarDialog as FileDialog

	var content := $Card/MarginContainer/Content as Control
	var main_row := content.get_node("MainRow") as Control
	var summary_content := main_row.get_node(
		"SummaryPanel/MarginContainer/SummaryContent"
	) as Control
	var form_content := main_row.get_node(
		"FormPanel/MarginContainer/FormContent"
	) as Control

	profile_name_preview_label = summary_content.get_node(
		"CurrentProfileValue"
	) as Label
	profile_email_preview_label = summary_content.get_node(
		"PreviewMetaRow/PreviewEmailBadge/MarginContainer/PreviewEmailLabel"
	) as Label
	profile_age_preview_label = summary_content.get_node(
		"PreviewMetaRow/PreviewAgeBadge/MarginContainer/PreviewAgeLabel"
	) as Label
	summary_save_label = summary_content.get_node("SummarySaveLabel") as Label
	avatar_placeholder_label = summary_content.get_node(
		"AvatarPreviewFrame/AvatarPlaceholder"
	) as Label
	var avatar_frame := summary_content.get_node("AvatarPreviewFrame") as Control
	avatar_preview = avatar_frame.get_node("AvatarPreview") as TextureRect
	avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar_frame.clip_contents = true
	username_input = form_content.get_node(
		"PrimaryFieldsRow/UsernameColumn/UsernameEdit"
	) as LineEdit

	var age_column := form_content.get_node("PrimaryFieldsRow/AgeColumn") as Control
	var age_column_label := age_column.get_node("AgeLabel") as Label
	age_column_label.text = "Fecha de nacimiento"
	birth_date_input = age_column.get_node("AgeEdit") as LineEdit
	_age_display_label = Label.new()
	_age_display_label.add_theme_font_size_override("font_size", 11)
	_age_display_label.modulate = Color(0.4, 0.4, 0.4, 1.0)
	age_column.add_child(_age_display_label)
	email_input = form_content.get_node("EmailEdit") as LineEdit
	_mail_verify_status_label = form_content.get_node("EmailVerifyStatusLabel") as Label
	_button_verify_email = form_content.get_node("EmailVerifyButton") as Button
	_button_verify_email.pressed.connect(_on_boton_verificar_mail_presionado)
	_mail_verify_hint_label = form_content.get_node("EmailVerifyHintLabel") as Label
	_email_notifications_checkbox = form_content.get_node(
		"EmailNotificationsCheckBox"
	) as CheckBox
	_email_notifications_hint_label = form_content.get_node(
		"EmailNotificationsHintLabel"
	) as Label
	avatar_path_input = form_content.get_node("AvatarRow/AvatarPathEdit") as LineEdit
	choose_avatar_button = form_content.get_node(
		"AvatarRow/ChooseAvatarButton"
	) as Button
	clear_avatar_button = form_content.get_node(
		"AvatarRow/ClearAvatarButton"
	) as Button
	feedback_label = form_content.get_node("RegisterMessage") as Label


func _configurar_ui_estatica() -> void:
	username_input.placeholder_text = "Nombre visible (opcional)"
	birth_date_input.placeholder_text = "AAAA-MM-DD (opcional)"
	email_input.placeholder_text = "Mail (opcional)"
	back_button.text = ""
	back_button.tooltip_text = "Volver"
	back_button.z_index = 100
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	move_child(back_button, -1)
	if not back_button.pressed.is_connected(_on_boton_volver_presionado):
		back_button.pressed.connect(_on_boton_volver_presionado)


func _cargar_estado_perfil_actual() -> void:
	var username := SaveManager.obtener_nombre_usuario_actual()
	username_input.text = "" if username == SaveManager.DEFAULT_PROFILE_NAME else username
	var birth_date := SaveManager.obtener_fecha_nacimiento_usuario_actual()
	birth_date_input.text = birth_date
	email_input.text = SaveManager.obtener_email_usuario_actual()
	avatar_path_input.text = SaveManager.obtener_ruta_avatar_usuario_actual()
	_configurar_checkbox_notificaciones_mail()
	_actualizar_estado_verificacion_mail()
	_perfil_online_sucio = false

	_refrescar_controles_avatar()
	_actualizar_etiquetas_vista_previa(
		username, email_input.text, birth_date_input.text, avatar_path_input.text
	)

	summary_save_label.visible = false

	# Sincroniza solo avatares ya vinculados a la cuenta activa.
	if (
		BackendSession.esta_logueado()
		and not avatar_path_input.text.strip_edges().is_empty()
		and SaveManager.es_ruta_avatar_vinculada(avatar_path_input.text)
	):
		_subir_avatar_al_backend_silencioso()


func _on_boton_elegir_avatar_presionado() -> void:
	avatar_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	avatar_dialog.popup_centered_ratio(0.75)


func _on_archivo_avatar_seleccionado(path: String) -> void:
	_aplicar_ruta_avatar(path)


func _on_boton_limpiar_avatar_presionado() -> void:
	avatar_path_input.text = ""
	_refrescar_controles_avatar()
	_refrescar_vista_previa_desde_formulario()
	SaveManager.actualizar_perfil_local(
		username_input.text.strip_edges(),
		birth_date_input.text.strip_edges(),
		email_input.text.strip_edges(),
		""
	)
	if BackendSession.esta_logueado():
		_establecer_feedback("Eliminando foto...", true)
		var del_result := await BackendSession.eliminar_avatar_online()
		if bool(del_result.get("ok", false)):
			_establecer_feedback("Foto eliminada.", true)
		else:
			_establecer_feedback("Foto eliminada localmente. Se sincronizará luego.", true)
	else:
		_establecer_feedback("Foto eliminada.", true)


func _marcar_perfil_online_sucio(_text: String = "") -> void:
	_perfil_online_sucio = true


func _intentar_autosave() -> void:
	var birth_date_text := birth_date_input.text.strip_edges()
	if not birth_date_text.is_empty():
		if not SaveLocalProfileHelperScript.es_fecha_nacimiento_valida(birth_date_text):
			_establecer_feedback(
				"La fecha de nacimiento debe tener formato AAAA-MM-DD o quedar vacía.",
				false
			)
			return

	var save_result: Dictionary = SaveManager.actualizar_perfil_local(
		username_input.text.strip_edges(),
		birth_date_text,
		email_input.text.strip_edges(),
		avatar_path_input.text
	)
	var is_ok: bool = bool(save_result.get("ok", false))
	if is_ok:
		var persisted_avatar := SaveManager.obtener_ruta_avatar_usuario_actual()
		if not persisted_avatar.is_empty() and persisted_avatar != avatar_path_input.text:
			avatar_path_input.text = persisted_avatar
			_refrescar_controles_avatar()
		if BackendSession.esta_logueado():
			var refresh := await ProfileMailSyncHelperScript.refrescar_perfil_servidor()
			if not bool(refresh.get("ok", false)):
				_establecer_feedback(
					ProfileMailSyncHelperScript.mensaje_error(
						{"ok": false, "status": 0, "code": "PROFILE_REFRESH_FAILED"}
					),
					false
				)
				return
			var form_mail := email_input.text.strip_edges()
			var necesita_sync_online := (
				_perfil_online_sucio
				or ProfileMailSyncHelperScript.formulario_difiere_del_servidor(form_mail)
			)
			if not necesita_sync_online:
				_establecer_feedback("Datos guardados correctamente.", true)
				return
			_establecer_feedback("Guardando datos...", true)
			await _sincronizar_perfil_al_backend()
		else:
			_establecer_feedback("Datos guardados correctamente.", true)
	else:
		_establecer_feedback(str(save_result.get("message", "Error al guardar")), false)


func _on_boton_registrar_presionado() -> void:
	_intentar_autosave()
	if BackendSession.esta_logueado() and not avatar_path_input.text.strip_edges().is_empty():
		_subir_avatar_al_backend()
	if SaveLocalProfileHelperScript.es_fecha_nacimiento_valida(
		birth_date_input.text.strip_edges()
	) or birth_date_input.text.strip_edges().is_empty():
		_ir_a_escena_retorno()


func _on_boton_login_presionado() -> void:
	_intentar_autosave()
	_ir_a_escena_retorno()


func _on_boton_volver_presionado() -> void:
	_intentar_autosave()
	_ir_a_escena_retorno()


func _refrescar_vista_previa_desde_formulario(_text: String = "") -> void:
	_actualizar_etiquetas_vista_previa(
		username_input.text.strip_edges(),
		email_input.text.strip_edges(),
		birth_date_input.text.strip_edges(),
		avatar_path_input.text
	)


func _actualizar_etiquetas_vista_previa(
	username: String,
	email: String,
	birth_date_text: String,
	avatar_path: String
) -> void:
	profile_name_preview_label.text = (
		username
		if not username.is_empty()
		else SaveManager.DEFAULT_PROFILE_NAME
	)
	profile_email_preview_label.text = "Mail: %s" % (email if not email.is_empty() else "sin dato")
	if BackendSession.esta_logueado() and not email.is_empty():
		if ProfileMailSyncHelperScript.formulario_difiere_del_servidor(email):
			profile_email_preview_label.text += " · sin sincronizar"
		elif _mail_esta_verificado():
			profile_email_preview_label.text += " · verificado"
		else:
			profile_email_preview_label.text += " · pendiente"
	var age_preview := SaveLocalProfileHelperScript.calcular_edad_desde_fecha_nacimiento(
		birth_date_text
	)
	profile_age_preview_label.text = (
		"Edad: %d" % age_preview if age_preview > 0 else "Edad: sin dato"
	)
	if is_instance_valid(_age_display_label):
		_age_display_label.text = "%d años" % age_preview if age_preview > 0 else ""
	avatar_preview.texture = SaveManager.cargar_textura_avatar(avatar_path)
	avatar_placeholder_label.visible = avatar_preview.texture == null


func _aplicar_ruta_avatar(path: String) -> void:
	avatar_path_input.text = path
	_refrescar_controles_avatar()
	_refrescar_vista_previa_desde_formulario()
	_intentar_autosave()
	if BackendSession.esta_logueado():
		_subir_avatar_al_backend()


func _on_email_input_cambiado(texto: String) -> void:
	if BackendSession.esta_logueado():
		if not ProfileMailSyncHelperScript.mails_coinciden(
			texto.strip_edges(),
			ProfileMailSyncHelperScript.obtener_mail_servidor()
		):
			BackendSession.limpiar_mail_verificado_en_cache()
	_actualizar_estado_verificacion_mail()
	_actualizar_checkbox_notificaciones_habilitado()


func _mail_formulario_difiere_del_servidor() -> bool:
	return ProfileMailSyncHelperScript.formulario_difiere_del_servidor(
		email_input.text.strip_edges()
	)


func _sincronizar_perfil_al_backend(
	silencioso: bool = false,
	forzar_mail: bool = false
) -> Dictionary:
	var form_mail := email_input.text.strip_edges()
	var formato := ProfileMailSyncHelperScript.validar_formato_mail(form_mail)
	if not form_mail.is_empty() and not bool(formato.get("ok", false)):
		return _responder_error_sync_perfil(
			{
				"ok": false,
				"status": 400,
				"code": "INVALID_MAIL",
				"error": str(formato.get("mensaje", "")),
			},
			silencioso
		)

	var refresh := await ProfileMailSyncHelperScript.refrescar_perfil_servidor()
	if BackendSession.esta_logueado() and not bool(refresh.get("ok", false)):
		return _responder_error_sync_perfil(
			{"ok": false, "status": 0, "code": "PROFILE_REFRESH_FAILED"},
			silencioso
		)

	if ProfileMailSyncHelperScript.debe_forzar_sync_mail(form_mail, forzar_mail):
		forzar_mail = true

	var notificaciones_mail: Variant = null
	if is_instance_valid(_email_notifications_checkbox):
		notificaciones_mail = _email_notifications_checkbox.button_pressed

	var result := await BackendSession.actualizar_perfil_online(
		username_input.text.strip_edges(),
		email_input.text.strip_edges(),
		birth_date_input.text.strip_edges(),
		notificaciones_mail,
		forzar_mail
	)
	result = ProfileMailSyncHelperScript.validar_resultado_sync(form_mail, result)
	if bool(result.get("ok", false)):
		_perfil_online_sucio = false
		if not bool(result.get("skipped", false)):
			AuthApi.aplicar_progreso_online_a_guardado_local()
		_actualizar_estado_verificacion_mail()
		_actualizar_checkbox_notificaciones_habilitado()
		var overlay_shown := _manejar_verificacion_respuesta_perfil(result, silencioso)
		if not silencioso and not overlay_shown:
			_establecer_feedback("Datos guardados correctamente.", true)
		return {"ok": true, "overlay_shown": overlay_shown}
	return _responder_error_sync_perfil(result, silencioso)


func _responder_error_sync_perfil(result: Dictionary, silencioso: bool) -> Dictionary:
	var status_code := int(result.get("status", 0))
	var server_error := str(result.get("error", ""))
	print(
		"[Auth] Profile sync failed (status=%d, code=%s): %s"
		% [status_code, str(result.get("code", "")), server_error]
	)
	if silencioso:
		return {"ok": false, "overlay_shown": false, "error": server_error, "code": result.get("code", "")}

	if str(result.get("code", "")) == "MAIL_NOT_VERIFIED":
		_responder_mail_no_verificado()
		return {"ok": false, "overlay_shown": false, "error": server_error, "code": result.get("code", "")}

	var mensaje := ProfileMailSyncHelperScript.mensaje_error(result)
	if mensaje.is_empty():
		mensaje = "No se pudo sincronizar. Revisá los datos."
	if status_code == 0 and str(result.get("code", "")) != "PROFILE_REFRESH_FAILED":
		mensaje = "Guardado localmente. Se sincronizará cuando haya conexión."
		_establecer_feedback(mensaje, true)
		return {"ok": false, "overlay_shown": false}

	_establecer_feedback(mensaje, false)
	return {"ok": false, "overlay_shown": false, "error": server_error, "code": result.get("code", "")}


func _manejar_verificacion_respuesta_perfil(result: Dictionary, silencioso: bool) -> bool:
	var evaluacion := AuthApi.evaluar_respuesta_verificacion(result)
	if not bool(evaluacion.get("show_overlay", false)):
		if not silencioso and not str(evaluacion.get("feedback", "")).is_empty():
			_establecer_feedback(str(evaluacion.get("feedback", "")), bool(evaluacion.get("feedback_ok", false)))
		return false
	if not silencioso:
		_establecer_feedback(str(evaluacion.get("feedback", "")), bool(evaluacion.get("feedback_ok", false)))
	_mostrar_pantalla_verificacion_mail(evaluacion)
	return true


func _subir_avatar_al_backend(silencioso: bool = false) -> void:
	var persisted_path := SaveManager.obtener_ruta_avatar_usuario_actual()
	if persisted_path.is_empty():
		return
	if not SaveManager.es_ruta_avatar_vinculada(persisted_path):
		print("[Auth] Avatar upload skipped: local avatar is not linked to active account.")
		return
	var bytes := FileAccess.get_file_as_bytes(persisted_path)
	if bytes.is_empty():
		return
	var base64_data := Marshalls.raw_to_base64(bytes)
	var ext := persisted_path.get_extension().to_lower()
	var mime_type := "image/png"
	if ext == "jpg" or ext == "jpeg":
		mime_type = "image/jpeg"
	elif ext == "webp":
		mime_type = "image/webp"
	if not silencioso:
		_establecer_feedback("Subiendo foto...", true)
	var result := await BackendSession.subir_avatar(base64_data, mime_type)
	if bool(result.get("ok", false)):
		if not silencioso:
			_establecer_feedback("Foto guardada ✓", true)
	else:
		print("[Auth] Avatar upload failed: ", result.get("error", ""))
		if not silencioso:
			if int(result.get("status", 0)) == 0:
				_establecer_feedback("Foto guardada localmente. Se subirá cuando haya conexión.", true)
			else:
				_establecer_feedback("No se pudo subir la foto al servidor.", false)


func _subir_avatar_al_backend_silencioso() -> void:
	_subir_avatar_al_backend(true)


func _on_notificaciones_mail_cambiadas(pressed: bool) -> void:
	if pressed and BackendSession.esta_logueado() and not AuthApi.mail_esta_verificado():
		_email_notifications_checkbox.button_pressed = false
		SaveManager.guardar_preferencia_notificaciones_mail_local(false)
		_responder_mail_no_verificado()
		return
	SaveManager.guardar_preferencia_notificaciones_mail_local(pressed)
	_marcar_perfil_online_sucio()
	_actualizar_checkbox_notificaciones_habilitado()
	if BackendSession.esta_logueado():
		_intentar_autosave()


func _mail_editado_sin_guardar_en_servidor() -> bool:
	return ProfileMailSyncHelperScript.formulario_difiere_del_servidor(
		email_input.text.strip_edges()
	)


func _mail_esta_verificado() -> bool:
	if not AuthApi.mail_esta_verificado():
		return false
	if _mail_editado_sin_guardar_en_servidor():
		return false
	return true


func _sincronizar_verificacion_mail_desde_servidor() -> void:
	if not BackendSession.esta_logueado():
		return
	var res: Dictionary = await BackendSession.refrescar_usuario_en_cache()
	if not bool(res.get("ok", false)):
		return
	_actualizar_estado_verificacion_mail()
	_actualizar_checkbox_notificaciones_habilitado()
	_refrescar_vista_previa_desde_formulario()


func _responder_mail_no_verificado() -> void:
	BackendSession.limpiar_mail_verificado_en_cache()
	_actualizar_estado_verificacion_mail()
	_actualizar_checkbox_notificaciones_habilitado()
	_refrescar_vista_previa_desde_formulario()
	_establecer_feedback(
		"Tu mail no está verificado. Usá «Verificar mail con código» para activar avisos.",
		false
	)


func _actualizar_estado_verificacion_mail() -> void:
	if (
		not is_instance_valid(_mail_verify_status_label)
		or not is_instance_valid(_button_verify_email)
		or not is_instance_valid(_mail_verify_hint_label)
	):
		return
	var mail := email_input.text.strip_edges()
	var online := BackendSession.esta_logueado()
	var seccion_visible := online and not mail.is_empty()
	var verificado := _mail_esta_verificado() if seccion_visible else false
	_mail_verify_status_label.visible = seccion_visible
	_button_verify_email.visible = seccion_visible
	_mail_verify_hint_label.visible = seccion_visible and not verificado
	if not seccion_visible:
		return
	if verificado:
		_mail_verify_status_label.text = "Mail verificado."
		_mail_verify_status_label.modulate = Color(0.219608, 0.380392, 0.235294, 1)
		_button_verify_email.visible = false
	else:
		_mail_verify_status_label.text = "Tu mail aún no está verificado."
		_mail_verify_status_label.modulate = Color(0.568627, 0.184314, 0.141176, 1)
		var sin_sync := _mail_editado_sin_guardar_en_servidor()
		if sin_sync:
			_mail_verify_status_label.text = (
				"Guardá el perfil para sincronizar el mail antes de verificar."
			)
		_button_verify_email.visible = true
		_button_verify_email.disabled = sin_sync
		_button_verify_email.tooltip_text = (
			"Primero guardá el perfil para sincronizar el mail."
			if sin_sync
			else "Te enviamos un código de 6 dígitos a tu casilla."
		)


func _on_boton_verificar_mail_presionado() -> void:
	if not BackendSession.esta_logueado():
		_establecer_feedback("Iniciá sesión para verificar tu mail.", false)
		return

	var form_mail := email_input.text.strip_edges()
	var precheck := ProfileMailSyncHelperScript.puede_solicitar_verificacion(form_mail)
	if not bool(precheck.get("ok", false)):
		_establecer_feedback(str(precheck.get("mensaje", "")), false)
		return

	if _mail_esta_verificado():
		_establecer_feedback("Tu mail ya está verificado.", true)
		_actualizar_estado_verificacion_mail()
		return

	_establecer_feedback("Guardando mail...", true)
	var sync := await _sincronizar_perfil_al_backend(true, true)
	if not bool(sync.get("ok", false)):
		var msg := ProfileMailSyncHelperScript.mensaje_error(sync)
		_establecer_feedback(
			msg if not msg.is_empty() else "No se pudo guardar el mail antes de verificar.",
			false
		)
		return
	if bool(sync.get("overlay_shown", false)):
		return

	_button_verify_email.disabled = true
	_establecer_feedback("Enviando código de verificación...", true)
	var mail_form := email_input.text.strip_edges()
	var res := await AuthApi.solicitar_codigo_verificacion(mail_form)
	_button_verify_email.disabled = false
	var evaluacion := AuthApi.evaluar_respuesta_verificacion(res)
	if not str(evaluacion.get("feedback", "")).is_empty():
		_establecer_feedback(str(evaluacion.get("feedback", "")), bool(evaluacion.get("feedback_ok", false)))
	if bool(evaluacion.get("show_overlay", false)):
		_mostrar_pantalla_verificacion_mail(evaluacion)


func _mostrar_pantalla_verificacion_mail(evaluacion: Dictionary = {}) -> void:
	if evaluacion.is_empty():
		evaluacion = {
			"show_overlay": true,
			"cooldown_seconds": 120.0,
			"feedback": "",
			"feedback_ok": true,
		}
	_ejecutar_overlay_verificacion_perfil(evaluacion)


func _ejecutar_overlay_verificacion_perfil(evaluacion: Dictionary) -> void:
	EmailVerificationBridge.iniciar_desde_perfil(evaluacion)


func _refrescar_tras_verificacion_mail() -> void:
	await _sincronizar_verificacion_mail_desde_servidor()
	_establecer_feedback("Mail verificado. Te enviamos un mail de bienvenida.", true)


func _procesar_retorno_verificacion_mail() -> void:
	EmailVerificationBridge.procesar_retorno_escena(self)


func _configurar_checkbox_notificaciones_mail() -> void:
	if not is_instance_valid(_email_notifications_checkbox):
		return
	_email_notifications_checkbox.visible = true
	if BackendSession.esta_logueado():
		var online_user := AuthApi.obtener_usuario_online()
		_email_notifications_checkbox.button_pressed = bool(
			online_user.get("email_notifications_enabled", false)
		)
	else:
		_email_notifications_checkbox.button_pressed = (
			SaveManager.obtener_preferencia_notificaciones_mail_local()
		)
	_actualizar_checkbox_notificaciones_habilitado()


func _actualizar_checkbox_notificaciones_habilitado() -> void:
	if not is_instance_valid(_email_notifications_checkbox):
		return
	var mail_ok := not email_input.text.strip_edges().is_empty()
	var verified := AuthApi.mail_esta_verificado()
	var puede_activar := mail_ok and verified
	if not puede_activar and _email_notifications_checkbox.button_pressed:
		_email_notifications_checkbox.button_pressed = false
		SaveManager.guardar_preferencia_notificaciones_mail_local(false)
	_email_notifications_checkbox.disabled = not puede_activar
	if is_instance_valid(_email_notifications_hint_label):
		_email_notifications_hint_label.visible = true
		if not mail_ok:
			_email_notifications_hint_label.text = (
				"Completá tu mail arriba para poder elegir notificaciones."
			)
		elif not verified:
			_email_notifications_hint_label.text = (
				"Verificá tu mail para activar recordatorios de racha."
			)
		else:
			_email_notifications_hint_label.text = "Activá o desactivá los avisos cuando quieras."
	if not mail_ok:
		_email_notifications_checkbox.tooltip_text = "Completá un mail en tu perfil."
	elif not verified:
		_email_notifications_checkbox.tooltip_text = "Verificá tu mail para activar recordatorios."
	else:
		_email_notifications_checkbox.tooltip_text = ""


func _refrescar_controles_avatar() -> void:
	var has_avatar: bool = not avatar_path_input.text.strip_edges().is_empty()
	choose_avatar_button.text = "Cambiar foto" if has_avatar else "Elegir foto"
	clear_avatar_button.visible = has_avatar


func _establecer_feedback(message: String, success: bool) -> void:
	feedback_label.visible = true
	feedback_label.text = message
	feedback_label.modulate = MiPaleta.FEEDBACK_OK if success else MiPaleta.FEEDBACK_ERROR


func _deberia_volver_a_intro() -> bool:
	return get_tree().root.get_meta(PROFILE_RETURN_SCENE_META, ARCHIVERO_SCENE) == INTRO_SCENE


func _ir_a_escena_retorno() -> void:
	if _deberia_volver_a_intro():
		GameSceneRouter.go_to_main_menu(get_tree())
		return
	GameSceneRouter.go_to_mode_selector(get_tree())
