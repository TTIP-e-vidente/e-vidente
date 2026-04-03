extends Control

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const INTRO_SCENE := "res://niveles/intro.tscn"

@onready var info_label: Label = $Card/MarginContainer/Content/InfoLabel
@onready var register_username: LineEdit = $Card/MarginContainer/Content/Tabs/Registro/Form/UsernameEdit
@onready var register_password: LineEdit = $Card/MarginContainer/Content/Tabs/Registro/Form/PasswordEdit
@onready var register_age: SpinBox = $Card/MarginContainer/Content/Tabs/Registro/Form/AgeEdit
@onready var register_email: LineEdit = $Card/MarginContainer/Content/Tabs/Registro/Form/EmailEdit
@onready var avatar_path_edit: LineEdit = $Card/MarginContainer/Content/Tabs/Registro/Form/AvatarRow/AvatarPathEdit
@onready var register_message: Label = $Card/MarginContainer/Content/Tabs/Registro/Form/RegisterMessage
@onready var avatar_preview: TextureRect = $Card/MarginContainer/Content/Tabs/Registro/Form/AvatarPreview
@onready var login_identifier: LineEdit = $Card/MarginContainer/Content/Tabs/IniciarSesion/Form/LoginIdentifierEdit
@onready var login_password: LineEdit = $Card/MarginContainer/Content/Tabs/IniciarSesion/Form/LoginPasswordEdit
@onready var login_message: Label = $Card/MarginContainer/Content/Tabs/IniciarSesion/Form/LoginMessage
@onready var avatar_dialog: FileDialog = $AvatarDialog


func _ready() -> void:
	info_label.text = _build_info_text()
	login_identifier.text = SaveManager.get_last_user_hint()
	_update_avatar_preview(avatar_path_edit.text)


func _on_choose_avatar_button_pressed() -> void:
	avatar_dialog.popup_centered_ratio(0.75)


func _on_avatar_dialog_file_selected(path: String) -> void:
	avatar_path_edit.text = path
	_update_avatar_preview(path)


func _on_register_button_pressed() -> void:
	register_message.text = ""
	var result := SaveManager.register_user(
		register_username.text,
		register_password.text,
		int(register_age.value),
		register_email.text,
		avatar_path_edit.text
	)
	register_message.text = str(result.get("message", ""))
	info_label.text = _build_info_text()
	if result.get("ok", false):
		_go_to_archivero()


func _on_login_button_pressed() -> void:
	login_message.text = ""
	var result := SaveManager.login_user(login_identifier.text, login_password.text)
	login_message.text = str(result.get("message", ""))
	if result.get("ok", false):
		_go_to_archivero()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(INTRO_SCENE)


func _update_avatar_preview(path: String) -> void:
	avatar_preview.texture = SaveManager.load_avatar_texture(path)


func _build_info_text() -> String:
	if SaveManager.has_accounts():
		return "Perfiles locales guardados: %d. Registra un usuario nuevo o inicia sesion con uno existente." % SaveManager.get_users_count()
	return "No hay cuentas locales todavia. Crea un perfil para guardar progreso, historial y avatar."


func _go_to_archivero() -> void:
	get_tree().change_scene_to_file(ARCHIVERO_SCENE)