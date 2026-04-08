extends Control

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const INTRO_SCENE := "res://niveles/intro.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ProfileFormHelperScript := preload("res://interface/helpers/ProfileFormHelper.gd")

@onready var current_profile_value: Label = $Card/MarginContainer/Content/MainRow/SummaryPanel/MarginContainer/SummaryContent/CurrentProfileValue
@onready var current_profile_email: Label = $Card/MarginContainer/Content/MainRow/SummaryPanel/MarginContainer/SummaryContent/PreviewMetaRow/PreviewEmailBadge/MarginContainer/PreviewEmailLabel
@onready var current_profile_age: Label = $Card/MarginContainer/Content/MainRow/SummaryPanel/MarginContainer/SummaryContent/PreviewMetaRow/PreviewAgeBadge/MarginContainer/PreviewAgeLabel
@onready var summary_save_label: Label = $Card/MarginContainer/Content/MainRow/SummaryPanel/MarginContainer/SummaryContent/SummarySaveLabel
@onready var avatar_placeholder: Label = $Card/MarginContainer/Content/MainRow/SummaryPanel/MarginContainer/SummaryContent/AvatarPreviewFrame/AvatarPlaceholder
@onready var register_username: LineEdit = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/PrimaryFieldsRow/UsernameColumn/UsernameEdit
@onready var register_age: LineEdit = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/PrimaryFieldsRow/AgeColumn/AgeEdit
@onready var register_email: LineEdit = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/EmailEdit
@onready var avatar_path_edit: LineEdit = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/AvatarRow/AvatarPathEdit
@onready var choose_avatar_button: Button = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/AvatarRow/ChooseAvatarButton
@onready var clear_avatar_button: Button = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/AvatarRow/ClearAvatarButton
@onready var register_message: Label = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/RegisterMessage
@onready var avatar_preview: TextureRect = $Card/MarginContainer/Content/MainRow/SummaryPanel/MarginContainer/SummaryContent/AvatarPreviewFrame/AvatarPreview
@onready var register_button: Button = $Card/MarginContainer/Content/FooterPanel/MarginContainer/Footer/RegisterButton
@onready var back_button: Button = $BackButton
@onready var avatar_dialog: FileDialog = $AvatarDialog

var _form_helper = ProfileFormHelperScript.new()


func _ready() -> void:
	var profile := SaveManager.get_current_user_profile()
	register_username.placeholder_text = "Nombre visible (opcional)"
	register_age.placeholder_text = "Edad (opcional)"
	register_email.placeholder_text = "Mail (opcional)"
	register_button.text = "Guardar perfil"
	back_button.text = ""
	back_button.tooltip_text = "Volver al menu" if _get_return_scene() == INTRO_SCENE else "Volver al Archivero"
	register_username.text = _form_helper.profile_name_for_form(profile, SaveManager.DEFAULT_PROFILE_NAME)
	register_age.text = _form_helper.age_for_form(profile)
	register_email.text = str(profile.get("email", ""))
	avatar_path_edit.text = str(profile.get("avatar_path", ""))
	_connect_live_preview_signals()
	_refresh_avatar_controls()
	_refresh_summary(profile)
	_set_feedback("Revisa la vista previa y guarda cuando este lista.", true)


func _on_choose_avatar_button_pressed() -> void:
	avatar_dialog.popup_centered_ratio(0.75)


func _on_avatar_dialog_file_selected(path: String) -> void:
	avatar_path_edit.text = path
	_refresh_avatar_controls()
	_refresh_live_preview()


func _on_clear_avatar_button_pressed() -> void:
	avatar_path_edit.text = ""
	_refresh_avatar_controls()
	_refresh_live_preview()


func _on_register_button_pressed() -> void:
	_set_feedback("", true)
	var age_result := _form_helper.parse_age(register_age.text)
	if not bool(age_result.get("ok", false)):
		_set_feedback(str(age_result.get("message", "Ingresa una edad valida o deja el campo vacio.")), false)
		return
	var result := SaveManager.update_local_profile(
		register_username.text,
		int(age_result.get("value", 0)),
		register_email.text,
		avatar_path_edit.text
	)
	var is_ok := bool(result.get("ok", false))
	_set_feedback(str(result.get("message", "")), is_ok)
	if is_ok:
		var saved_profile := SaveManager.get_current_user_profile()
		register_username.text = _form_helper.profile_name_for_form(saved_profile, SaveManager.DEFAULT_PROFILE_NAME)
		register_age.text = _form_helper.age_for_form(saved_profile)
		register_email.text = str(saved_profile.get("email", ""))
		avatar_path_edit.text = str(saved_profile.get("avatar_path", ""))
		_refresh_avatar_controls()
		_refresh_summary(saved_profile)
	if result.get("ok", false):
		_go_to_return_scene()


func _on_login_button_pressed() -> void:
	_go_to_return_scene()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(_get_return_scene())


func _update_avatar_preview(path: String) -> void:
	avatar_preview.texture = SaveManager.load_avatar_texture(path)
	avatar_placeholder.visible = avatar_preview.texture == null


func _build_info_text() -> String:
	return "Edita solo lo que quieras mostrar. Todo queda guardado en este dispositivo y se refleja en Mi progreso."


func _connect_live_preview_signals() -> void:
	for field in [register_username, register_age, register_email]:
		if not field.text_changed.is_connected(_on_profile_field_changed):
			field.text_changed.connect(_on_profile_field_changed)


func _on_profile_field_changed(_new_text: String) -> void:
	_refresh_live_preview()


func _refresh_summary(profile: Dictionary) -> void:
	_apply_profile_preview(str(profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)), str(profile.get("email", "")), _form_helper.age_for_form(profile))
	_update_avatar_preview(str(profile.get("avatar_path", "")))
	summary_save_label.text = _form_helper.build_summary_save_text(SaveManager.get_save_status())


func _refresh_live_preview() -> void:
	_apply_profile_preview(register_username.text, register_email.text, register_age.text)
	_update_avatar_preview(avatar_path_edit.text)


func _apply_profile_preview(profile_name: String, email: String, age_text: String) -> void:
	var preview := _form_helper.build_preview(profile_name, email, age_text, SaveManager.DEFAULT_PROFILE_NAME)
	current_profile_value.text = str(preview.get("username", SaveManager.DEFAULT_PROFILE_NAME))
	current_profile_email.text = str(preview.get("email", "Mail: sin dato"))
	current_profile_age.text = str(preview.get("age", "Edad: sin dato"))


func _refresh_avatar_controls() -> void:
	var has_avatar := not avatar_path_edit.text.strip_edges().is_empty()
	choose_avatar_button.text = "Cambiar foto" if has_avatar else "Elegir foto"
	clear_avatar_button.visible = has_avatar


func _set_feedback(message: String, success: bool) -> void:
	register_message.text = message
	register_message.modulate = Color(0.219608, 0.380392, 0.235294, 1) if success else Color(0.568627, 0.184314, 0.141176, 1)


func _get_return_scene() -> String:
	var return_scene = get_tree().root.get_meta(PROFILE_RETURN_SCENE_META, ARCHIVERO_SCENE)
	if return_scene == INTRO_SCENE:
		return INTRO_SCENE
	return ARCHIVERO_SCENE


func _go_to_return_scene() -> void:
	get_tree().change_scene_to_file(_get_return_scene())