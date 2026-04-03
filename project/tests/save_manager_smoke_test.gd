extends SceneTree

const TEST_USERNAME := "ci_save_user"
const TEST_PASSWORD := "password123"
const TEST_EMAIL := "ci_save_user@example.com"
const TEST_AGE := 24
const TEMP_AVATAR_PATH := "user://ci_avatar.png"
const STORED_AVATAR_PATH := "user://avatars/ci_save_user.png"

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_cleanup_test_files()
	await process_frame

	var temp_avatar_absolute := ProjectSettings.globalize_path(TEMP_AVATAR_PATH)
	var avatar_error := _create_temp_avatar(temp_avatar_absolute)
	_assert(avatar_error == OK, "No se pudo crear el avatar temporal para la prueba")

	SaveManager.load_data()
	var register_result := SaveManager.register_user(
		TEST_USERNAME,
		TEST_PASSWORD,
		TEST_AGE,
		TEST_EMAIL,
		temp_avatar_absolute
	)
	_assert(bool(register_result.get("ok", false)), "Registro local fallido: %s" % register_result.get("message", "sin detalle"))
	_assert(SaveManager.is_authenticated(), "El usuario deberia quedar autenticado luego del registro")
	_assert(FileAccess.file_exists(SaveManager.SAVE_PATH), "No se genero el archivo local de guardado")
	_assert(FileAccess.file_exists(STORED_AVATAR_PATH), "No se copio el avatar al almacenamiento local")
	_assert(SaveManager.get_current_user_avatar_texture() != null, "No se pudo recargar el avatar desde user://")

	var auth_scene := load("res://interface/auth.tscn")
	_assert(auth_scene != null, "No se pudo cargar la escena de autenticacion")
	if auth_scene != null:
		var auth_instance := auth_scene.instantiate()
		root.add_child(auth_instance)
		await process_frame
		auth_instance.queue_free()

	Global.items_level[1][Global.LEVEL_STATUS_INDEX] = true
	SaveManager.record_level_completed("celiaquia", 1)
	SaveManager.logout()
	_assert(not SaveManager.is_authenticated(), "Cerrar sesion no limpio la sesion actual")

	var login_result := SaveManager.login_user(TEST_EMAIL, TEST_PASSWORD)
	_assert(bool(login_result.get("ok", false)), "Login local fallido: %s" % login_result.get("message", "sin detalle"))
	var progress_summary := Global.get_progress_summary()
	_assert(int(progress_summary.get("celiaquia", 0)) == 1, "El progreso guardado no se restauro al volver a iniciar sesion")

	var archivero_scene := load("res://interface/archivero.tscn")
	_assert(archivero_scene != null, "No se pudo cargar la escena del Archivero")
	if archivero_scene != null:
		var archivero_instance := archivero_scene.instantiate()
		root.add_child(archivero_instance)
		await process_frame
		archivero_instance.queue_free()

	var history := SaveManager.get_current_user_history()
	_assert(history.size() >= 3, "El historial local no registro suficientes eventos del flujo smoke test")

	_cleanup_test_files()
	await process_frame
	quit(1 if failed else 0)


func _create_temp_avatar(destination: String) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.95, 0.74, 0.32, 1.0))
	return image.save_png(destination)


func _cleanup_test_files() -> void:
	Global.reset_progress()
	SaveManager.current_user_key = ""
	for relative_path in [SaveManager.SAVE_PATH, TEMP_AVATAR_PATH, STORED_AVATAR_PATH]:
		var absolute_path := ProjectSettings.globalize_path(relative_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	SaveManager.load_data()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("SAVE MANAGER SMOKE TEST FAILED: %s" % message)