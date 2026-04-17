extends Control

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
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
	_cache_ui_nodes()
	_configure_static_ui()
	_connect_live_preview_signals()
	_load_current_profile_state()
	_set_feedback("Revisa la vista previa y guarda cuando este lista.", true)


func _cache_ui_nodes() -> void:
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


func _configure_static_ui() -> void:
	username_input.placeholder_text = "Nombre visible (opcional)"
	age_input.placeholder_text = "Edad (opcional)"
	email_input.placeholder_text = "Mail (opcional)"
	save_profile_button.text = "Guardar perfil"
	back_button.text = ""
	back_button.tooltip_text = (
		"Volver al menu"
		if _should_return_to_intro()
		else "Volver al Archivero"
	)


func _load_current_profile_state() -> void:
	var profile: Dictionary = SaveManager.get_current_user_profile()
	_populate_form_from_profile(profile)
	_refresh_avatar_controls()
	var username := str(profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)).strip_edges()
	var email := str(profile.get("email", "")).strip_edges()
	var age := int(profile.get("age", 0))
	_update_preview_labels(username, email, "" if age <= 0 else str(age), str(profile.get("avatar_path", "")))
	var last_reason := str(SaveManager.get_save_status().get("last_saved_reason", ""))
	summary_save_label.text = "Ultimo guardado: %s" % last_reason.replace("_", " ") if not last_reason.is_empty() else "Ultimo guardado: sin escrituras registradas."


func _on_choose_avatar_button_pressed() -> void:
	avatar_dialog.popup_centered_ratio(0.75)


func _on_avatar_dialog_file_selected(path: String) -> void:
	_apply_avatar_path(path)


func _on_clear_avatar_button_pressed() -> void:
	_apply_avatar_path("")


func _on_register_button_pressed() -> void:
	_set_feedback("", true)
	var age_text := age_input.text.strip_edges()
	var parsed_age := 0
	if not age_text.is_empty():
		if not age_text.is_valid_int() or int(age_text) < 0:
			_set_feedback("La edad debe ser un numero entero o quedar vacia.", false)
			return
		parsed_age = int(age_text)

	var save_result: Dictionary = SaveManager.update_local_profile(
		username_input.text,
		parsed_age,
		email_input.text,
		avatar_path_input.text
	)
	_on_profile_saved(save_result)


func _on_login_button_pressed() -> void:
	_go_to_return_scene()


func _on_back_button_pressed() -> void:
	_go_to_return_scene()


func _connect_live_preview_signals() -> void:
	for field in [username_input, age_input, email_input]:
		if not field.text_changed.is_connected(_on_profile_field_changed):
			field.text_changed.connect(_on_profile_field_changed)


func _on_profile_field_changed(_new_text: String) -> void:
	_refresh_preview_from_form()


func _refresh_preview_from_form() -> void:
	var age_text := age_input.text.strip_edges()
	var age_display: String
	if age_text.is_empty():
		age_display = ""
	elif not age_text.is_valid_int() or int(age_text) < 0:
		age_display = "revisar"
	else:
		age_display = age_text
	_update_preview_labels(
		username_input.text.strip_edges(),
		email_input.text.strip_edges(),
		age_display,
		avatar_path_input.text
	)


func _update_preview_labels(username: String, email: String, age_text: String, avatar_path: String) -> void:
	profile_name_preview_label.text = username if not username.is_empty() else SaveManager.DEFAULT_PROFILE_NAME
	profile_email_preview_label.text = "Mail: %s" % (email if not email.is_empty() else "sin dato")
	profile_age_preview_label.text = "Edad: %s" % (age_text if not age_text.is_empty() else "sin dato")
	_update_avatar_preview(avatar_path)


func _populate_form_from_profile(profile: Dictionary) -> void:
	var username := str(profile.get("username", ""))
	username_input.text = "" if username == SaveManager.DEFAULT_PROFILE_NAME else username

	var age := int(profile.get("age", 0))
	age_input.text = "" if age <= 0 else str(age)

	email_input.text = str(profile.get("email", ""))
	avatar_path_input.text = str(profile.get("avatar_path", ""))


func _update_avatar_preview(path: String) -> void:
	avatar_preview.texture = SaveManager.load_avatar_texture(path)
	avatar_placeholder_label.visible = avatar_preview.texture == null


func _apply_avatar_path(path: String) -> void:
	avatar_path_input.text = path
	_refresh_avatar_controls()
	_refresh_preview_from_form()


func _refresh_avatar_controls() -> void:
	var has_avatar: bool = not avatar_path_input.text.strip_edges().is_empty()
	choose_avatar_button.text = "Cambiar foto" if has_avatar else "Elegir foto"
	clear_avatar_button.visible = has_avatar


func _on_profile_saved(save_result: Dictionary) -> void:
	var is_ok: bool = bool(save_result.get("ok", false))
	_set_feedback(str(save_result.get("message", "")), is_ok)
	if not is_ok:
		return

	_load_current_profile_state()
	_go_to_return_scene()


func _set_feedback(message: String, success: bool) -> void:
	feedback_label.text = message
	feedback_label.modulate = (
		Color(0.219608, 0.380392, 0.235294, 1)
		if success
		else Color(0.568627, 0.184314, 0.141176, 1)
	)


func _should_return_to_intro() -> bool:
	return get_tree().root.get_meta(PROFILE_RETURN_SCENE_META, ARCHIVERO_SCENE) == INTRO_SCENE


func _go_to_return_scene() -> void:
	if _should_return_to_intro():
		GameSceneRouter.go_to_main_menu(get_tree())
		return
	GameSceneRouter.go_to_archivero(get_tree())
