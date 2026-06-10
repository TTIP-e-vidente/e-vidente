extends Control

const ARCHIVERO_SCENE := "res://niveles/selector.tscn"
const INTRO_SCENE := "res://niveles/intro.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"

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

func _ready() -> void:
	_cachear_nodos_ui()
	_configurar_ui_estatica()
	username_input.text_changed.connect(_refrescar_vista_previa_desde_formulario)
	birth_date_input.text_changed.connect(_refrescar_vista_previa_desde_formulario)
	email_input.text_changed.connect(_refrescar_vista_previa_desde_formulario)
	username_input.focus_exited.connect(_intentar_autosave)
	birth_date_input.focus_exited.connect(_intentar_autosave)
	email_input.focus_exited.connect(_intentar_autosave)
	_cargar_estado_perfil_actual()
	_establecer_feedback("Los cambios se guardan automáticamente.", true)
	BackendSession.session_expired.connect(_on_sesion_expirada)


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
	back_button.tooltip_text = ""


func _cargar_estado_perfil_actual() -> void:
	var username := SaveManager.obtener_nombre_usuario_actual()
	username_input.text = "" if username == SaveManager.DEFAULT_PROFILE_NAME else username
	var birth_date := SaveManager.obtener_fecha_nacimiento_usuario_actual()
	birth_date_input.text = birth_date
	email_input.text = SaveManager.obtener_email_usuario_actual()
	avatar_path_input.text = SaveManager.obtener_ruta_avatar_usuario_actual()

	_refrescar_controles_avatar()
	_actualizar_etiquetas_vista_previa(
		username, email_input.text, birth_date_input.text, avatar_path_input.text
	)

	var last_reason := SaveManager.obtener_motivo_ultimo_guardado()
	if last_reason.is_empty():
		summary_save_label.text = "Ultimo guardado: sin escrituras registradas."
	else:
		summary_save_label.text = "Ultimo guardado: %s" % last_reason.replace("_", " ")
	summary_save_label.visible = true

	# Sincroniza el avatar local con el backend al abrir la pantalla de perfil.
	# Cubre el caso de usuarios que ya tenían avatar antes de que existiera este feature.
	if BackendSession.esta_logueado() and not avatar_path_input.text.strip_edges().is_empty():
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
			_establecer_feedback("Guardando datos...", true)
			_sincronizar_perfil_al_backend()
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


const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)


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


func _sincronizar_perfil_al_backend() -> void:
	var result := await BackendSession.actualizar_perfil_online(
		username_input.text.strip_edges(),
		email_input.text.strip_edges(),
		birth_date_input.text.strip_edges()
	)
	if bool(result.get("ok", false)):
		_establecer_feedback("Datos guardados correctamente.", true)
		return
	var status_code := int(result.get("status", 0))
	var server_error := str(result.get("error", ""))
	print("[Auth] Profile sync failed (status=%d): %s" % [status_code, server_error])
	match status_code:
		409:
			_establecer_feedback("Ese mail ya está en uso por otra cuenta.", false)
		400:
			var msg := server_error if not server_error.is_empty() else "Datos inválidos."
			_establecer_feedback(msg, false)
		0:
			_establecer_feedback("Guardado localmente. Se sincronizará cuando haya conexión.", true)
		_:
			_establecer_feedback("No se pudo sincronizar. Revisá los datos.", false)


func _subir_avatar_al_backend(silencioso: bool = false) -> void:
	var persisted_path := SaveManager.obtener_ruta_avatar_usuario_actual()
	if persisted_path.is_empty():
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


func _refrescar_controles_avatar() -> void:
	var has_avatar: bool = not avatar_path_input.text.strip_edges().is_empty()
	choose_avatar_button.text = "Cambiar foto" if has_avatar else "Elegir foto"
	clear_avatar_button.visible = has_avatar


func _establecer_feedback(message: String, success: bool) -> void:
	feedback_label.visible = true
	feedback_label.text = message
	feedback_label.modulate = (
		Color(0.219608, 0.380392, 0.235294, 1)
		if success
		else Color(0.568627, 0.184314, 0.141176, 1)
	)


func _deberia_volver_a_intro() -> bool:
	return get_tree().root.get_meta(PROFILE_RETURN_SCENE_META, ARCHIVERO_SCENE) == INTRO_SCENE


func _ir_a_escena_retorno() -> void:
	if _deberia_volver_a_intro():
		GameSceneRouter.go_to_main_menu(get_tree())
		return
	GameSceneRouter.go_to_mode_selector(get_tree())
