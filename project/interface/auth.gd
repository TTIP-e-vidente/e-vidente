extends Control

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const INTRO_SCENE := "res://niveles/intro.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ProfileFormHelperScript := preload("res://interface/helpers/ProfileFormHelper.gd")

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

var _form_helper = ProfileFormHelperScript.new()


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
	var current_profile: Dictionary = SaveManager.get_current_user_profile()
	_populate_form_from_profile(current_profile)
	_refresh_avatar_controls()
	_refresh_summary_from_profile(current_profile)


func _on_choose_avatar_button_pressed() -> void:
	avatar_dialog.popup_centered_ratio(0.75)


func _on_avatar_dialog_file_selected(path: String) -> void:
	_apply_avatar_path(path)


func _on_clear_avatar_button_pressed() -> void:
	_apply_avatar_path("")


func _on_register_button_pressed() -> void:
	_set_feedback("", true)
	var age_result: Dictionary = _form_helper.parse_age(age_input.text)
	if not bool(age_result.get("ok", false)):
		_set_feedback(
			str(age_result.get(
				"message",
				"Ingresa una edad valida o deja el campo vacio."
			)),
			false
		)
		return

	var save_result: Dictionary = SaveManager.update_local_profile(
		username_input.text,
		int(age_result.get("value", 0)),
		email_input.text,
		avatar_path_input.text
	)
	_handle_profile_save_result(save_result)


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


func _refresh_summary_from_profile(profile: Dictionary) -> void:
	_render_profile_preview(
		str(profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)),
		str(profile.get("email", "")),
		_form_helper.age_for_form(profile)
	)
	_update_avatar_preview(str(profile.get("avatar_path", "")))
	_refresh_summary_save_status()


func _refresh_preview_from_form() -> void:
	_render_profile_preview(username_input.text, email_input.text, age_input.text)
	_update_avatar_preview(avatar_path_input.text)


func _refresh_summary_save_status() -> void:
	summary_save_label.text = _form_helper.build_summary_save_text(
		SaveManager.get_save_status()
	)


func _populate_form_from_profile(profile: Dictionary) -> void:
	username_input.text = _form_helper.profile_name_for_form(
		profile,
		SaveManager.DEFAULT_PROFILE_NAME
	)
	age_input.text = _form_helper.age_for_form(profile)
	email_input.text = str(profile.get("email", ""))
	avatar_path_input.text = str(profile.get("avatar_path", ""))


func _render_profile_preview(profile_name: String, email: String, age_text: String) -> void:
	var preview: Dictionary = _form_helper.build_preview(
		profile_name,
		email,
		age_text,
		SaveManager.DEFAULT_PROFILE_NAME
	)
	profile_name_preview_label.text = str(
		preview.get("username", SaveManager.DEFAULT_PROFILE_NAME)
	)
	profile_email_preview_label.text = str(preview.get("email", "Mail: sin dato"))
	profile_age_preview_label.text = str(preview.get("age", "Edad: sin dato"))


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


func _handle_profile_save_result(save_result: Dictionary) -> void:
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
