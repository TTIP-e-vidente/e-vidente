extends SceneTree

const TEST_USERNAME := "validation_user"
const TEST_PASSWORD := "password123"
const TEST_EMAIL := "validation_user@example.com"
const SECOND_USERNAME := "second_user"
const SECOND_EMAIL := "second_user@example.com"
const TEMP_AVATAR_PATH := "user://validation_avatar.png"
const TEMP_AVATAR_INVALID_PATH := "user://validation_avatar.txt"
const STORED_AVATAR_PATH := "user://avatars/validation_user.png"

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_cleanup_test_files()
	await process_frame

	var avatar_absolute := ProjectSettings.globalize_path(TEMP_AVATAR_PATH)
	_assert(_create_temp_avatar(avatar_absolute) == OK, "No se pudo crear el avatar PNG de prueba")
	_assert(_create_invalid_avatar(ProjectSettings.globalize_path(TEMP_AVATAR_INVALID_PATH)) == OK, "No se pudo crear el archivo avatar invalido")

	SaveManager.load_data()

	var short_password := SaveManager.register_user(TEST_USERNAME, "short", 20, TEST_EMAIL, avatar_absolute)
	_assert(not bool(short_password.get("ok", true)), "Deberia rechazar contrasena corta")

	var invalid_email := SaveManager.register_user(TEST_USERNAME, TEST_PASSWORD, 20, "mail-invalido", avatar_absolute)
	_assert(not bool(invalid_email.get("ok", true)), "Deberia rechazar mail invalido")

	var missing_avatar := SaveManager.register_user(TEST_USERNAME, TEST_PASSWORD, 20, TEST_EMAIL, "")
	_assert(not bool(missing_avatar.get("ok", true)), "Deberia requerir avatar")

	var invalid_avatar := SaveManager.register_user(TEST_USERNAME, TEST_PASSWORD, 20, TEST_EMAIL, ProjectSettings.globalize_path(TEMP_AVATAR_INVALID_PATH))
	_assert(not bool(invalid_avatar.get("ok", true)), "Deberia rechazar avatar no valido")

	var register_result := SaveManager.register_user(TEST_USERNAME, TEST_PASSWORD, 20, TEST_EMAIL, avatar_absolute)
	_assert(bool(register_result.get("ok", false)), "Registro base fallido: %s" % register_result.get("message", "sin detalle"))
	_assert(SaveManager.get_users_count() == 1, "Luego del primer registro deberia existir un usuario")
	_assert(SaveManager.get_last_user_hint() == TEST_USERNAME, "El hint del ultimo usuario deberia quedar actualizado")

	var duplicate_username := SaveManager.register_user(TEST_USERNAME, TEST_PASSWORD, 21, SECOND_EMAIL, avatar_absolute)
	_assert(not bool(duplicate_username.get("ok", true)), "Deberia rechazar usuario duplicado")

	var duplicate_email := SaveManager.register_user(SECOND_USERNAME, TEST_PASSWORD, 21, TEST_EMAIL, avatar_absolute)
	_assert(not bool(duplicate_email.get("ok", true)), "Deberia rechazar mail duplicado")

	Global.items_level[2][Global.LEVEL_STATUS_INDEX] = true
	SaveManager.record_manual_save()
	_assert(FileAccess.file_exists(SaveManager.SAVE_PATH), "El guardado manual deberia escribir save_data.json")

	SaveManager.logout()
	_assert(not SaveManager.is_authenticated(), "El logout deberia limpiar la sesion")
	_assert(Global.get_progress_summary().get("total", -1) == 0, "El logout deberia resetear el progreso en memoria")

	var wrong_password := SaveManager.login_user(TEST_EMAIL, "otra-pass")
	_assert(not bool(wrong_password.get("ok", true)), "Deberia rechazar login con contrasena incorrecta")

	var login_by_username := SaveManager.login_user(TEST_USERNAME, TEST_PASSWORD)
	_assert(bool(login_by_username.get("ok", false)), "Deberia permitir login por username")
	_assert(FileAccess.file_exists(STORED_AVATAR_PATH), "El avatar persistido deberia existir tras el registro")
	_assert(int(Global.get_progress_summary().get("celiaquia", 0)) == 1, "La recarga deberia restaurar progreso guardado")

	SaveManager.load_data()
	_assert(SaveManager.get_users_count() == 1, "La recarga desde disco deberia conservar el usuario")
	_assert(SaveManager.get_last_user_hint() == TEST_USERNAME, "La recarga desde disco deberia conservar el ultimo usuario")

	var broken_file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	_assert(broken_file != null, "No se pudo abrir save_data.json para corrupcion controlada")
	if broken_file != null:
		broken_file.store_string("{ esto no es json }")
	SaveManager.load_data()
	_assert(SaveManager.get_users_count() == 0, "Un save corrupto deberia reiniciarse a estado vacio")
	_assert(not SaveManager.is_authenticated(), "Luego de un save corrupto no deberia quedar sesion valida")

	_cleanup_test_files()
	await process_frame
	quit(1 if failed else 0)


func _create_temp_avatar(destination: String) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.28, 0.67, 0.9, 1.0))
	return image.save_png(destination)


func _create_invalid_avatar(destination: String) -> int:
	var invalid_file := FileAccess.open(destination, FileAccess.WRITE)
	if invalid_file == null:
		return ERR_CANT_CREATE
	invalid_file.store_string("no es una imagen")
	return OK


func _cleanup_test_files() -> void:
	Global.reset_progress()
	SaveManager.current_user_key = ""
	for relative_path in [
		SaveManager.SAVE_PATH,
		TEMP_AVATAR_PATH,
		TEMP_AVATAR_INVALID_PATH,
		STORED_AVATAR_PATH,
		"user://avatars/second_user.png"
	]:
		var absolute_path := ProjectSettings.globalize_path(relative_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	SaveManager.load_data()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("SAVE MANAGER VALIDATION TEST FAILED: %s" % message)