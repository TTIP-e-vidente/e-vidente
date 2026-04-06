extends SceneTree

const TEST_USERNAME := "validation_user"
const TEST_EMAIL := "validation_user@example.com"
const TEMP_AVATAR_PATH := "user://validation_avatar.png"
const TEMP_AVATAR_INVALID_PATH := "user://validation_avatar.txt"
const STORED_AVATAR_PATH := "user://avatars/local_profile.png"

var SaveManager
var Global
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_resolve_singletons()
	_assert(SaveManager != null, "No se encontro el autoload SaveManager")
	_assert(Global != null, "No se encontro el autoload Global")
	if failed:
		quit(1)
		return
	_cleanup_test_files()
	await process_frame

	var avatar_absolute := ProjectSettings.globalize_path(TEMP_AVATAR_PATH)
	_assert(_create_temp_avatar(avatar_absolute) == OK, "No se pudo crear el avatar PNG de prueba")
	_assert(_create_invalid_avatar(ProjectSettings.globalize_path(TEMP_AVATAR_INVALID_PATH)) == OK, "No se pudo crear el archivo avatar invalido")

	SaveManager.load_data()
	_assert(SaveManager.is_authenticated(), "El perfil local deberia inicializarse automaticamente")
	var invalid_session_title: Dictionary = SaveManager.validate_session_title("ab")
	_assert(not bool(invalid_session_title.get("ok", true)), "El nombre de una partida no deberia aceptar menos de 3 caracteres")
	var valid_session_title: Dictionary = SaveManager.validate_session_title("  Mi partida celiaca  ")
	_assert(bool(valid_session_title.get("ok", false)), "Un nombre razonable de partida deberia validarse correctamente")
	_assert(str(valid_session_title.get("title", "")) == "Mi partida celiaca", "El nombre de la partida deberia guardarse normalizado")

	var short_name: Dictionary = SaveManager.update_local_profile("ab", 20, TEST_EMAIL, avatar_absolute)
	_assert(not bool(short_name.get("ok", true)), "Deberia rechazar nombres visibles demasiado cortos")

	var invalid_email: Dictionary = SaveManager.update_local_profile(TEST_USERNAME, 20, "mail-invalido", avatar_absolute)
	_assert(not bool(invalid_email.get("ok", true)), "Deberia rechazar mail invalido")

	var invalid_age: Dictionary = SaveManager.update_local_profile(TEST_USERNAME, -1, TEST_EMAIL, avatar_absolute)
	_assert(not bool(invalid_age.get("ok", true)), "Deberia rechazar edad negativa")

	var invalid_avatar: Dictionary = SaveManager.update_local_profile(TEST_USERNAME, 20, TEST_EMAIL, ProjectSettings.globalize_path(TEMP_AVATAR_INVALID_PATH))
	_assert(not bool(invalid_avatar.get("ok", true)), "Deberia rechazar avatar no valido")

	var update_result: Dictionary = SaveManager.update_local_profile(TEST_USERNAME, 20, TEST_EMAIL, avatar_absolute)
	_assert(bool(update_result.get("ok", false)), "Actualizacion base del perfil fallida: %s" % update_result.get("message", "sin detalle"))
	_assert(SaveManager.get_users_count() == 1, "Deberia existir un unico perfil local")
	_assert(SaveManager.get_last_user_hint() == TEST_USERNAME, "El hint del perfil deberia quedar actualizado")
	_assert(FileAccess.file_exists(STORED_AVATAR_PATH), "El avatar persistido deberia existir tras actualizar el perfil")

	var clear_avatar_result: Dictionary = SaveManager.update_local_profile(TEST_USERNAME, 20, TEST_EMAIL, "")
	_assert(bool(clear_avatar_result.get("ok", false)), "Borrar el avatar local deberia persistirse correctamente")
	_assert(str(SaveManager.get_current_user_profile().get("avatar_path", "")) == "", "Borrar el avatar deberia limpiar la ruta persistida")
	_assert(SaveManager.get_current_user_avatar_texture() == null, "Borrar el avatar deberia dejar de exponer una textura cargable")
	_assert(not FileAccess.file_exists(STORED_AVATAR_PATH), "Borrar el avatar deberia limpiar el archivo persistido del sandbox")

	Global.current_level = 2
	Global.items_level[2][Global.LEVEL_STATUS_INDEX] = true
	SaveManager.set_resume_to_level("celiaquia", Global.current_level)
	SaveManager.record_manual_save()
	_assert(FileAccess.file_exists(SaveManager.SAVE_PATH), "El guardado manual deberia escribir save_data.json")
	_assert(FileAccess.file_exists(SaveManager.BACKUP_SAVE_PATH), "El guardado robusto deberia mantener un backup reciente")
	_assert(not FileAccess.file_exists(SaveManager.TEMP_SAVE_PATH), "No deberia quedar un archivo temporal luego de guardar correctamente")
	var saved_status: Dictionary = SaveManager.get_save_status()
	_assert(str(saved_status.get("last_saved_reason", "")) == "manual_save", "La metadata del save deberia registrar el guardado manual")
	_assert(int(saved_status.get("write_count", 0)) > 0, "La metadata del save deberia llevar conteo de escrituras")
	_assert(int(saved_status.get("session_count", 0)) == 1, "El primer guardado jugable deberia crear una unica partida")

	Global.reset_progress()
	var resume_state: Dictionary = SaveManager.load_progress_and_get_resume_state()
	_assert(int(Global.get_progress_summary().get("celiaquia", 0)) == 1, "La recarga deberia restaurar progreso guardado")
	_assert(str(resume_state.get("context", "")) == SaveManager.RESUME_CONTEXT_LEVEL, "La recarga deberia recuperar el contexto del nivel guardado")
	_assert(int(resume_state.get("level_number", 0)) == 2, "La recarga deberia recuperar el capitulo a retomar")
	_assert(Global.current_level == 2, "La recarga deberia restaurar el capitulo actual para retomar")
	SaveManager.record_level_completed("celiaquia", 2)
	var next_resume_state: Dictionary = SaveManager.get_resume_state()
	_assert(str(next_resume_state.get("context", "")) == SaveManager.RESUME_CONTEXT_LEVEL, "Completar un capitulo deberia mantener la reanudacion dentro del flujo de juego")
	_assert(int(next_resume_state.get("level_number", 0)) == 3, "Completar un capitulo deberia dejar preparada la carga del siguiente")
	SaveManager.set_resume_to_book("celiaquia", true)
	var recovered_resume_state: Dictionary = SaveManager.get_resume_state()
	_assert(str(recovered_resume_state.get("context", "")) == SaveManager.RESUME_CONTEXT_LEVEL, "El resume no deberia degradarse a selector de capitulos si existe una reanudacion jugable mas precisa")
	_assert(int(recovered_resume_state.get("level_number", 0)) == 3, "La reanudacion deberia seguir apuntando al siguiente capitulo despues de una degradacion accidental")
	SaveManager.record_manual_save()

	SaveManager.load_data()
	_assert(SaveManager.get_users_count() == 1, "La recarga desde disco deberia conservar el perfil local")
	_assert(SaveManager.get_last_user_hint() == TEST_USERNAME, "La recarga desde disco deberia conservar el ultimo usuario")
	var repaired_resume_state: Dictionary = SaveManager.get_resume_state()
	_assert(str(repaired_resume_state.get("context", "")) == SaveManager.RESUME_CONTEXT_LEVEL, "La carga deberia reparar en disco un resume_state degradado")
	_assert(int(repaired_resume_state.get("level_number", 0)) == 3, "La reparacion del save deberia conservar el siguiente capitulo listo para retomar")
	_assert(str(SaveManager.get_save_status().get("last_saved_reason", "")) == "load_repair", "La auto-reparacion del resume deberia registrarse como load_repair")

	var original_session_id: String = SaveManager.get_active_save_slot_id()
	var new_game_result: bool = SaveManager.start_new_game("Recorrido celiaquia")
	_assert(new_game_result, "Nueva partida deberia poder resetear y persistir el progreso actual")
	var new_session_id: String = SaveManager.get_active_save_slot_id()
	_assert(not new_session_id.is_empty(), "Nueva partida deberia dejar una sesion activa")
	_assert(new_session_id != original_session_id, "Nueva partida no deberia pisar la sesion anterior")
	_assert(SaveManager.list_save_slots().size() == 2, "Nueva partida deberia conservar la partida anterior como otro slot")
	_assert(str(SaveManager.get_active_save_slot_summary().get("title", "")) == "Recorrido celiaquia", "Nueva partida deberia conservar el nombre elegido para identificarla")
	_assert(int(Global.get_progress_summary().get("total", -1)) == 0, "Nueva partida deberia reiniciar el progreso acumulado")
	_assert(str(SaveManager.get_save_status().get("last_saved_reason", "")) == "new_game", "Nueva partida deberia registrarse en la metadata del save")
	_assert(str(SaveManager.get_resume_state().get("context", "")) == SaveManager.RESUME_CONTEXT_HUB, "Nueva partida deberia volver a dejar el resume en el Archivero")
	_assert(SaveManager.can_resume_game(), "Una nueva partida ya creada deberia quedar disponible para retomar")
	_assert(SaveManager.can_resume_game(original_session_id), "La partida anterior deberia seguir disponible para cargar")
	var previous_resume_state: Dictionary = SaveManager.load_slot_and_get_resume_state(original_session_id)
	_assert(int(Global.get_progress_summary().get("celiaquia", 0)) == 1, "La partida anterior deberia seguir conservando el progreso jugable")
	_assert(int(previous_resume_state.get("level_number", 0)) == 3, "La partida anterior deberia seguir apuntando al siguiente capitulo")
	var new_slot_resume_state: Dictionary = SaveManager.load_slot_and_get_resume_state(new_session_id)
	_assert(int(Global.get_progress_summary().get("total", -1)) == 0, "La nueva partida deberia poder recargarse vacia")
	_assert(str(new_slot_resume_state.get("context", "")) == SaveManager.RESUME_CONTEXT_HUB, "La nueva partida deberia reanudar desde el Archivero")

	var broken_file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	_assert(broken_file != null, "No se pudo abrir save_data.json para corrupcion controlada")
	if broken_file != null:
		broken_file.store_string("{ esto no es json }")
	SaveManager.load_data()
	_assert(SaveManager.get_users_count() == 1, "Con backup disponible deberia conservarse un unico perfil local")
	_assert(SaveManager.is_authenticated(), "Con backup disponible la persistencia deberia seguir activa")
	_assert(SaveManager.get_current_user_profile().get("username", "") == TEST_USERNAME, "Con backup disponible deberia recuperarse el ultimo perfil valido")
	_assert(SaveManager.list_save_slots().size() == 1, "Con backup disponible deberia recuperarse el ultimo snapshot valido, aunque sea anterior a la nueva partida")
	_assert(int(Global.get_progress_summary().get("celiaquia", 0)) == 1, "Con backup disponible deberia recuperarse el progreso guardado del snapshot anterior")
	_assert(FileAccess.file_exists(SaveManager.SAVE_PATH), "La recuperacion deberia reescribir el save principal")
	var recovered_status: Dictionary = SaveManager.get_save_status()
	_assert(str(recovered_status.get("state", "")) == "recovered", "La metadata runtime deberia indicar que el save fue recuperado")
	_assert(str(recovered_status.get("recovered_from", "")) == "backup", "La metadata runtime deberia indicar la fuente de recuperacion")
	SaveManager.load_slot_and_get_resume_state(original_session_id)
	_assert(int(Global.get_progress_summary().get("celiaquia", 0)) == 1, "Tras recuperar desde backup deberia poder cargarse la partida anterior")

	var reset_result: Dictionary = SaveManager.reset_all_progress()
	_assert(bool(reset_result.get("ok", false)), "Reiniciar el progreso local deberia persistirse correctamente")
	_assert(int(Global.get_progress_summary().get("total", -1)) == 0, "Reiniciar el progreso deberia limpiar todo el avance jugable")
	_assert(not SaveManager.can_resume_game(), "Reiniciar el progreso no deberia dejar una partida retomable")
	_assert(SaveManager.list_save_slots(true).is_empty(), "Reiniciar el progreso deberia borrar todas las sesiones guardadas")
	_assert(SaveManager.get_current_user_history().is_empty(), "Reiniciar el progreso deberia limpiar el historial local")
	_assert(str(SaveManager.get_current_user_profile().get("username", "")) == TEST_USERNAME, "Reiniciar el progreso no deberia borrar el perfil local")
	_assert(str(SaveManager.get_save_status().get("last_saved_reason", "")) == "progress_reset", "El save deberia registrar el reinicio del progreso")

	SaveManager.load_data()
	_assert(int(Global.get_progress_summary().get("total", -1)) == 0, "El progreso reiniciado deberia seguir limpio despues de recargar")
	_assert(not SaveManager.can_resume_game(), "Despues de recargar no deberia reaparecer una partida retomable")
	_assert(SaveManager.list_save_slots(true).is_empty(), "Despues de recargar no deberian reaparecer sesiones borradas")
	_assert(str(SaveManager.get_current_user_profile().get("username", "")) == TEST_USERNAME, "El perfil local deberia seguir intacto despues de recargar")

	_cleanup_test_files()
	await process_frame
	quit(1 if failed else 0)


func _resolve_singletons() -> void:
	if SaveManager == null:
		SaveManager = root.get_node_or_null("/root/SaveManager")
	if Global == null:
		Global = root.get_node_or_null("/root/Global")


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
	for relative_path in [
		SaveManager.SAVE_PATH,
		SaveManager.TEMP_SAVE_PATH,
		SaveManager.BACKUP_SAVE_PATH,
		TEMP_AVATAR_PATH,
		TEMP_AVATAR_INVALID_PATH,
		STORED_AVATAR_PATH
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