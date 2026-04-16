extends SceneTree

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

	var legacy_payload := {
		"version": 1,
		"last_user": "chosen_user",
		"users": {
			"other_user": {
				"username": "Otro perfil",
				"age": 12,
				"email": "otro@example.com",
				"avatar_path": "",
				"created_at": "2026-03-01T10:00:00",
				"updated_at": "2026-03-01T10:10:00",
				"progress": {
					"current_level": 1,
					"celiaquia": [false, false, false, false, false, false],
					"veganismo": [false, false, false, false, false, false],
					"veganismo_celiaquia": [false, false, false, false, false, false]
				},
				"history": []
			},
			"chosen_user": {
				"username": "Perfil legado",
				"age": 34,
				"email": "legado@example.com",
				"avatar_path": "",
				"created_at": "2026-03-02T10:00:00",
				"updated_at": "2026-03-03T11:00:00",
				"progress": {
					"current_level": 4,
					"celiaquia": [true, true, false, false, false, false],
					"veganismo": [false, true, false, false, false, false],
					"veganismo_celiaquia": [false, false, false, false, false, false]
				},
				"history": [
					{
						"timestamp": "2026-03-03T11:00:00",
						"message": "Cuenta creada",
						"metadata": {"type": "register"}
					}
				]
			}
		}
	}

	var save_file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	_assert(save_file != null, "No se pudo crear un save legado controlado")
	if save_file != null:
		save_file.store_string(JSON.stringify(legacy_payload, "\t"))
		save_file.flush()
		save_file = null
		await process_frame

	SaveManager.load_data()

	var profile: Dictionary = SaveManager.get_current_user_profile()
	_assert(str(profile.get("username", "")) == "Perfil legado", "La migracion deberia tomar el usuario apuntado por last_user")
	_assert(str(profile.get("email", "")) == "legado@example.com", "La migracion deberia conservar el mail del save legado")
	_assert(int(profile.get("age", 0)) == 34, "La migracion deberia conservar la edad del save legado")
	_assert(SaveManager.get_users_count() == 1, "Tras migrar deberia existir un unico perfil local")
	_assert(str(SaveManager.get_save_status().get("last_saved_reason", "")) == "legacy_migration", "La metadata deberia marcar que el save provino de una migracion")

	var summary: Dictionary = Global.get_progress_summary()
	_assert(int(summary.get("celiaquia", 0)) == 2, "La migracion deberia restaurar progreso de celiaquia")
	_assert(int(summary.get("veganismo", 0)) == 1, "La migracion deberia restaurar progreso de veganismo")
	_assert(SaveManager.get_current_save_history().size() == 1, "La migracion deberia conservar el historial legado")
	_assert(SaveManager.can_resume_current_save(), "La migracion deberia dejar un save retomable cuando hay progreso")

	SaveManager.record_manual_save()
	var migrated_file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	_assert(migrated_file != null, "No se pudo reabrir el save ya migrado")
	if migrated_file != null:
		var migrated_payload = JSON.parse_string(migrated_file.get_as_text())
		_assert(migrated_payload is Dictionary, "El save migrado deberia seguir siendo JSON valido")
		if migrated_payload is Dictionary:
			_assert(migrated_payload.has("profile"), "El save migrado deberia escribirse con el formato nuevo basado en profile")
			_assert(migrated_payload.has("progress"), "El save migrado deberia persistir el progreso directamente en la raiz")
			_assert(not migrated_payload.has("sessions"), "El save migrado ya no deberia persistir contenedores de sesiones")
			_assert(not migrated_payload.has("active_session_id"), "El save migrado ya no deberia persistir una sesion activa")
			_assert(not migrated_payload.has("users"), "El save migrado ya no deberia persistir el formato viejo users/last_user")
			_assert(str(migrated_payload.get("save_meta", {}).get("last_saved_reason", "")) == "manual_save", "El save migrado deberia poder volver a guardarse con metadata nueva")

	_cleanup_test_files()
	await process_frame
	quit(1 if failed else 0)


func _resolve_singletons() -> void:
	if SaveManager == null:
		SaveManager = root.get_node_or_null("/root/SaveManager")
	if Global == null:
		Global = root.get_node_or_null("/root/Global")


func _cleanup_test_files() -> void:
	Global.reset_progress()
	for relative_path in [
		SaveManager.SAVE_PATH,
		SaveManager.TEMP_SAVE_PATH,
		SaveManager.BACKUP_SAVE_PATH
	]:
		var absolute_path := ProjectSettings.globalize_path(relative_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	SaveManager.load_data()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("SAVE MANAGER LEGACY TEST FAILED: %s" % message)