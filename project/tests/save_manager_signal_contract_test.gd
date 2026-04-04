extends SceneTree

const TEST_USERNAME := "signal_user"
const TEST_EMAIL := "signal_user@example.com"
const TEMP_AVATAR_PATH := "user://signal_avatar.png"
const STORED_AVATAR_PATH := "user://avatars/local_profile.png"

var failed := false
var user_registered_count := 0
var user_logged_in_count := 0
var user_logged_out_count := 0
var progress_saved_count := 0
var progress_loaded_count := 0
var save_status_events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_cleanup_test_files()
	await process_frame

	_connect_signals()
	_reset_counters()

	var avatar_absolute := ProjectSettings.globalize_path(TEMP_AVATAR_PATH)
	_assert(_create_temp_avatar(avatar_absolute) == OK, "No se pudo crear el avatar del test de señales")

	var profile_result := SaveManager.update_local_profile(TEST_USERNAME, 31, TEST_EMAIL, avatar_absolute)
	await process_frame
	_assert(bool(profile_result.get("ok", false)), "La actualizacion del perfil deberia funcionar para probar señales")
	_assert(user_registered_count == 1, "Actualizar el perfil deberia emitir user_registered una vez")
	_assert(user_logged_in_count == 1, "Actualizar el perfil deberia emitir user_logged_in una vez")
	_assert(progress_loaded_count == 1, "Actualizar el perfil deberia emitir progress_loaded una vez")
	_assert(_has_save_state("dirty"), "Actualizar el perfil deberia marcar el save como dirty antes de persistir")
	_assert(_has_saved_reason("profile_updated"), "Actualizar el perfil deberia publicar profile_updated en save_status_changed")
	_assert(FileAccess.file_exists(STORED_AVATAR_PATH), "El avatar persistido deberia existir despues de la actualizacion")

	SaveManager.record_manual_save()
	await process_frame
	_assert(progress_saved_count == 1, "El guardado manual deberia emitir progress_saved una vez")
	_assert(_has_saved_reason("manual_save"), "El guardado manual deberia reflejar manual_save en save_status_changed")

	SaveManager.load_current_user_progress(true)
	await process_frame
	_assert(progress_loaded_count == 2, "La carga explicita del progreso deberia volver a emitir progress_loaded")

	SaveManager.logout()
	await process_frame
	_assert(user_logged_out_count == 1, "El logout deberia emitir user_logged_out")
	_assert(_has_saved_reason("progress_sync"), "El logout deberia sincronizar el progreso antes de salir")

	var login_result := SaveManager.login_user("", "")
	await process_frame
	_assert(bool(login_result.get("ok", false)), "El login local simplificado deberia seguir funcionando")
	_assert(user_logged_in_count == 2, "El login local deberia emitir user_logged_in nuevamente")

	for index in range(SaveManager.HISTORY_LIMIT + 7):
		SaveManager.record_manual_save()
	await process_frame
	_assert(SaveManager.get_current_user_history().size() == SaveManager.HISTORY_LIMIT, "El historial deberia respetar el limite maximo configurado")

	_cleanup_test_files()
	await process_frame
	quit(1 if failed else 0)


func _connect_signals() -> void:
	SaveManager.user_registered.connect(_on_user_registered)
	SaveManager.user_logged_in.connect(_on_user_logged_in)
	SaveManager.user_logged_out.connect(_on_user_logged_out)
	SaveManager.progress_saved.connect(_on_progress_saved)
	SaveManager.progress_loaded.connect(_on_progress_loaded)
	SaveManager.save_status_changed.connect(_on_save_status_changed)


func _reset_counters() -> void:
	user_registered_count = 0
	user_logged_in_count = 0
	user_logged_out_count = 0
	progress_saved_count = 0
	progress_loaded_count = 0
	save_status_events.clear()


func _create_temp_avatar(destination: String) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.72, 0.38, 0.95, 1.0))
	return image.save_png(destination)


func _cleanup_test_files() -> void:
	Global.reset_progress()
	for relative_path in [
		SaveManager.SAVE_PATH,
		SaveManager.TEMP_SAVE_PATH,
		SaveManager.BACKUP_SAVE_PATH,
		TEMP_AVATAR_PATH,
		STORED_AVATAR_PATH
	]:
		var absolute_path := ProjectSettings.globalize_path(relative_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	SaveManager.load_data()


func _has_save_state(state: String) -> bool:
	for event in save_status_events:
		if str(event.get("state", "")) == state:
			return true
	return false


func _has_saved_reason(reason: String) -> bool:
	for event in save_status_events:
		if str(event.get("last_saved_reason", "")) == reason:
			return true
	return false


func _on_user_registered(_profile: Dictionary) -> void:
	user_registered_count += 1


func _on_user_logged_in(_profile: Dictionary) -> void:
	user_logged_in_count += 1


func _on_user_logged_out() -> void:
	user_logged_out_count += 1


func _on_progress_saved(_profile: Dictionary) -> void:
	progress_saved_count += 1


func _on_progress_loaded(_profile: Dictionary) -> void:
	progress_loaded_count += 1


func _on_save_status_changed(status: Dictionary) -> void:
	save_status_events.append(status.duplicate(true))


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("SAVE MANAGER SIGNAL TEST FAILED: %s" % message)