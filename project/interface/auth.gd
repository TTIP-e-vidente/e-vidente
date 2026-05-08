extends Control

const ARCHIVERO_SCENE := "res://niveles/selector.tscn"
const INTRO_SCENE := "res://niveles/intro.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

var profile_name_preview_label: Label
var profile_email_preview_label: Label
var profile_age_preview_label: Label
var summary_save_label: Label
var avatar_placeholder_label: Label
var username_input: LineEdit
var age_input: LineEdit
var email_input: LineEdit
var avatar_path_input: LineEdit
var choose_avatar_button: Button
var clear_avatar_button: Button
var feedback_label: Label
var avatar_preview: TextureRect
var save_profile_button: Button
var back_button: Button
var avatar_dialog: FileDialog

func _ready() -> void:
	_cachear_nodos_ui()
	_configurar_ui_estatica()
	username_input.text_changed.connect(_refrescar_vista_previa_desde_formulario)
	age_input.text_changed.connect(_refrescar_vista_previa_desde_formulario)
	email_input.text_changed.connect(_refrescar_vista_previa_desde_formulario)
	_cargar_estado_perfil_actual()
	_establecer_feedback("Revisa la vista previa y guarda cuando este lista.", true)


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
	var footer := content.get_node("FooterPanel/MarginContainer/Footer") as Control

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
	avatar_preview = summary_content.get_node(
		"AvatarPreviewFrame/AvatarPreview"
	) as TextureRect
	username_input = form_content.get_node(
		"PrimaryFieldsRow/UsernameColumn/UsernameEdit"
	) as LineEdit
	age_input = form_content.get_node(
		"PrimaryFieldsRow/AgeColumn/AgeEdit"
	) as LineEdit
	email_input = form_content.get_node("EmailEdit") as LineEdit
	avatar_path_input = form_content.get_node("AvatarRow/AvatarPathEdit") as LineEdit
	choose_avatar_button = form_content.get_node(
		"AvatarRow/ChooseAvatarButton"
	) as Button
	clear_avatar_button = form_content.get_node(
		"AvatarRow/ClearAvatarButton"
	) as Button
	feedback_label = form_content.get_node("RegisterMessage") as Label
	save_profile_button = footer.get_node("RegisterButton") as Button


func _configurar_ui_estatica() -> void:
	username_input.placeholder_text = "Nombre visible (opcional)"
	age_input.placeholder_text = "Edad (opcional)"
	email_input.placeholder_text = "Mail (opcional)"
	save_profile_button.text = "Guardar perfil"
	back_button.text = ""
	back_button.tooltip_text = ""


func _cargar_estado_perfil_actual() -> void:
	var username := SaveManager.obtener_nombre_usuario_actual()
	username_input.text = "" if username == SaveManager.DEFAULT_PROFILE_NAME else username
	var age := SaveManager.obtener_edad_usuario_actual()
	age_input.text = "" if age <= 0 else str(age)
	email_input.text = SaveManager.obtener_email_usuario_actual()
	avatar_path_input.text = SaveManager.obtener_ruta_avatar_usuario_actual()

	# Actualizar controles de avatar y vista previa
	_refrescar_controles_avatar()
	_actualizar_etiquetas_vista_previa(username, email_input.text, age_input.text, avatar_path_input.text)

	# Mostrar ultimo guardado
	var last_reason := SaveManager.obtener_motivo_ultimo_guardado()
	if last_reason.is_empty():
		summary_save_label.text = "Ultimo guardado: sin escrituras registradas."
	else:
		summary_save_label.text = "Ultimo guardado: %s" % last_reason.replace("_", " ")


func _on_boton_elegir_avatar_presionado() -> void:
	avatar_dialog.popup_centered_ratio(0.75)


func _on_archivo_avatar_seleccionado(path: String) -> void:
	_aplicar_ruta_avatar(path)


func _on_boton_limpiar_avatar_presionado() -> void:
	_aplicar_ruta_avatar("")


func _on_boton_registrar_presionado() -> void:
	_establecer_feedback("", true)
	var age_text := age_input.text.strip_edges()
	var parsed_age := 0
	if not age_text.is_empty():
		if not age_text.is_valid_int() or int(age_text) < 0:
			_establecer_feedback("La edad debe ser un numero entero o quedar vacia.", false)
			return
		parsed_age = int(age_text)

	var save_result: Dictionary = SaveManager.actualizar_perfil_local(
		username_input.text,
		parsed_age,
		email_input.text,
		avatar_path_input.text
	)
	var is_ok: bool = bool(save_result.get("ok", false))
	_establecer_feedback(str(save_result.get("message", "")), is_ok)
	if is_ok:
		_cargar_estado_perfil_actual()
		_ir_a_escena_retorno()


func _on_boton_login_presionado() -> void:
	_ir_a_escena_retorno()


func _on_boton_volver_presionado() -> void:
	_ir_a_escena_retorno()


func _refrescar_vista_previa_desde_formulario(_text: String = "") -> void:
	_actualizar_etiquetas_vista_previa(
		username_input.text.strip_edges(),
		email_input.text.strip_edges(),
		age_input.text.strip_edges(),
		avatar_path_input.text
	)


func _actualizar_etiquetas_vista_previa(
	username: String,
	email: String,
	age_text: String,
	avatar_path: String
) -> void:
	profile_name_preview_label.text = (
		username
		if not username.is_empty()
		else SaveManager.DEFAULT_PROFILE_NAME
	)
	profile_email_preview_label.text = "Mail: %s" % (email if not email.is_empty() else "sin dato")
	profile_age_preview_label.text = "Edad: %s" % (
		age_text if not age_text.is_empty() else "sin dato"
	)
	avatar_preview.texture = SaveManager.cargar_textura_avatar(avatar_path)
	avatar_placeholder_label.visible = avatar_preview.texture == null


func _aplicar_ruta_avatar(path: String) -> void:
	avatar_path_input.text = path
	_refrescar_controles_avatar()
	_refrescar_vista_previa_desde_formulario()


func _refrescar_controles_avatar() -> void:
	var has_avatar: bool = not avatar_path_input.text.strip_edges().is_empty()
	choose_avatar_button.text = "Cambiar foto" if has_avatar else "Elegir foto"
	clear_avatar_button.visible = has_avatar


func _establecer_feedback(message: String, success: bool) -> void:
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
