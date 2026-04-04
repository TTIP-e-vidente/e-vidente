extends Control

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const INTRO_SCENE := "res://niveles/intro.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"

@onready var title_label: Label = $Card/MarginContainer/Content/Header/Title
@onready var subtitle_label: Label = $Card/MarginContainer/Content/Header/Subtitle
@onready var info_label: Label = $Card/MarginContainer/Content/Header/InfoLabel
@onready var current_profile_value: Label = $Card/MarginContainer/Content/MainRow/SummaryPanel/MarginContainer/SummaryContent/CurrentProfileValue
@onready var summary_save_label: Label = $Card/MarginContainer/Content/MainRow/SummaryPanel/MarginContainer/SummaryContent/SummarySaveLabel
@onready var register_username: LineEdit = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/UsernameEdit
@onready var register_age: LineEdit = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/AgeEdit
@onready var register_email: LineEdit = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/EmailEdit
@onready var avatar_path_edit: LineEdit = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/AvatarRow/AvatarPathEdit
@onready var choose_avatar_button: Button = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/AvatarRow/ChooseAvatarButton
@onready var register_message: Label = $Card/MarginContainer/Content/MainRow/FormPanel/MarginContainer/FormContent/RegisterMessage
@onready var avatar_preview: TextureRect = $Card/MarginContainer/Content/MainRow/SummaryPanel/MarginContainer/SummaryContent/AvatarPreviewFrame/AvatarPreview
@onready var register_button: Button = $Card/MarginContainer/Content/Footer/RegisterButton
@onready var back_button: Button = $Card/MarginContainer/Content/Footer/BackButton
@onready var avatar_dialog: FileDialog = $AvatarDialog


func _ready() -> void:
	var profile := SaveManager.get_current_user_profile()
	title_label.text = "Perfil local"
	subtitle_label.text = "El progreso se guarda en este dispositivo. Completa solo los datos que te sirvan."
	info_label.text = _build_info_text()
	register_username.placeholder_text = "Nombre visible (opcional)"
	register_age.placeholder_text = "Edad (opcional)"
	register_email.placeholder_text = "Mail (opcional)"
	choose_avatar_button.text = "Elegir foto"
	register_button.text = "Guardar y volver" if _get_return_scene() == INTRO_SCENE else "Guardar y volver al Archivero"
	back_button.text = "Volver al menu" if _get_return_scene() == INTRO_SCENE else "Volver al Archivero"
	register_username.text = _profile_name_for_form(profile)
	register_age.text = _age_for_form(profile)
	register_email.text = str(profile.get("email", ""))
	avatar_path_edit.text = str(profile.get("avatar_path", ""))
	_refresh_summary(profile)
	_set_feedback("Los cambios se guardan en este dispositivo.", true)
	_update_avatar_preview(avatar_path_edit.text)


func _on_choose_avatar_button_pressed() -> void:
	avatar_dialog.popup_centered_ratio(0.75)


func _on_avatar_dialog_file_selected(path: String) -> void:
	avatar_path_edit.text = path
	_update_avatar_preview(path)


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
		_refresh_summary(SaveManager.get_current_user_profile())
	if result.get("ok", false):
		_go_to_return_scene()


func _on_login_button_pressed() -> void:
	_go_to_return_scene()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(_get_return_scene())


func _update_avatar_preview(path: String) -> void:
	avatar_preview.texture = SaveManager.load_avatar_texture(path)


func _build_info_text() -> String:
	return "Hay un unico perfil local por dispositivo. No necesitas login ni registro para conservar avance, avatar e historial."


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
	var profile_name := str(profile.get("username", SaveManager.DEFAULT_PROFILE_NAME))
	current_profile_value.text = profile_name
	var save_status := SaveManager.get_save_status()
	var last_reason := str(save_status.get("last_saved_reason", ""))
	if last_reason.is_empty():
		summary_save_label.text = "Ultimo guardado: todavia no hay escrituras registradas."
	else:
		summary_save_label.text = "Ultimo guardado: %s" % _format_save_reason(last_reason)


func _format_save_reason(reason: String) -> String:
	match reason:
		"profile_updated":
			return "perfil actualizado"
		"manual_save":
			return "guardado manual"
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