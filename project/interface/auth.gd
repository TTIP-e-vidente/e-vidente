extends Control

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const INTRO_SCENE := "res://niveles/intro.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"

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


func _ready() -> void:
	var profile := SaveManager.get_current_user_profile()
	register_username.placeholder_text = "Nombre visible (opcional)"
	register_age.placeholder_text = "Edad (opcional)"
	register_email.placeholder_text = "Mail (opcional)"
	register_button.text = "Guardar perfil"
	back_button.text = ""
	back_button.tooltip_text = "Volver al menu" if _get_return_scene() == INTRO_SCENE else "Volver al Archivero"
	register_username.text = _profile_name_for_form(profile)
	register_age.text = _age_for_form(profile)
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
	var age_result := _parse_age(register_age.text)
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
		register_username.text = _profile_name_for_form(saved_profile)
		register_age.text = _age_for_form(saved_profile)
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


func _profile_name_for_form(profile: Dictionary) -> String:
	var username := str(profile.get("username", ""))
	if username == SaveManager.DEFAULT_PROFILE_NAME:
		return ""
	return username


func _age_for_form(profile: Dictionary) -> String:
	var age := int(profile.get("age", 0))
	if age <= 0:
		return ""
	return str(age)


func _parse_age(value: String) -> Dictionary:
	var clean_value := value.strip_edges()
	if clean_value.is_empty():
		return {"ok": true, "value": 0}
	if not clean_value.is_valid_int():
		return {"ok": false, "message": "La edad debe ser un numero entero o quedar vacia."}
	var parsed_age := int(clean_value)
	if parsed_age < 0:
		return {"ok": false, "message": "La edad no puede ser negativa."}
	return {"ok": true, "value": parsed_age}


func _refresh_summary(profile: Dictionary) -> void:
	_apply_profile_preview(
		str(profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)),
		str(profile.get("email", "")),
		_age_for_form(profile)
	)
	_update_avatar_preview(str(profile.get("avatar_path", "")))
	var save_status := SaveManager.get_save_status()
	var last_reason := str(save_status.get("last_saved_reason", ""))
	if last_reason.is_empty():
		summary_save_label.text = "Ultimo guardado: todavia no hay escrituras registradas."
	else:
		summary_save_label.text = "Ultimo guardado: %s" % _format_save_reason(last_reason)


func _refresh_live_preview() -> void:
	_apply_profile_preview(register_username.text, register_email.text, register_age.text)
	_update_avatar_preview(avatar_path_edit.text)


func _apply_profile_preview(profile_name: String, email: String, age_text: String) -> void:
	var clean_name := profile_name.strip_edges()
	current_profile_value.text = clean_name if not clean_name.is_empty() else SaveManager.DEFAULT_PROFILE_NAME
	current_profile_email.text = "Mail: %s" % _format_optional_preview_text(email)
	current_profile_age.text = _format_preview_age(age_text)


func _format_optional_preview_text(value: String) -> String:
	var clean_value := value.strip_edges()
	if clean_value.is_empty():
		return "sin dato"
	return clean_value


func _format_preview_age(value: String) -> String:
	var clean_value := value.strip_edges()
	if clean_value.is_empty():
		return "Edad: sin dato"
	if not clean_value.is_valid_int() or int(clean_value) < 0:
		return "Edad: revisar"
	return "Edad: %s" % clean_value


func _refresh_avatar_controls() -> void:
	var has_avatar := not avatar_path_edit.text.strip_edges().is_empty()
	choose_avatar_button.text = "Cambiar foto" if has_avatar else "Elegir foto"
	clear_avatar_button.visible = has_avatar


func _format_save_reason(reason: String) -> String:
	match reason:
		"profile_updated":
			return "perfil actualizado"
		"manual_save":
			return "guardado manual"
		"progress_reset":
			return "progreso reiniciado"
		"level_completed":
			return "avance persistido"
		"progress_sync":
			return "sincronizacion de progreso"
		"load_repair":
			return "reparacion del save"
		_:
			return reason.replace("_", " ")


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