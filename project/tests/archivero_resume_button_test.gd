extends SceneTree

const TEST_USERNAME := "resume_button_user"
const TEST_EMAIL := "resume_button_user@example.com"
const LEVEL_SCENE := "res://niveles/nivel_1/Level.tscn"

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

	SaveManager.load_data()
	var profile_result: Dictionary = SaveManager.update_local_profile(TEST_USERNAME, 24, TEST_EMAIL, "")
	_assert(bool(profile_result.get("ok", false)), "No se pudo preparar el perfil local para el test del boton de reanudacion")
	Global.mark_level_completed("celiaquia", 1)
	Global.mark_level_completed("celiaquia", 2)
	SaveManager.set_resume_to_level("celiaquia", 3)
	SaveManager.record_manual_save()

	var archivero_scene: PackedScene = load("res://interface/archivero.tscn") as PackedScene
	_assert(archivero_scene != null, "No se pudo cargar la escena del Archivero")
	if archivero_scene != null:
		var archivero_instance: Node = archivero_scene.instantiate()
		root.add_child(archivero_instance)
		await process_frame

		var profile_toggle_button: Button = archivero_instance.get_node("ProfileOverlayLayer/ProfileToggleButton")
		var resume_now_button: Button = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/StatusRow/ResumeCard/MarginContainer/ResumeContent/ResumeNowButton")

		_assert(profile_toggle_button != null, "Archivero deberia exponer el acceso al perfil")
		_assert(resume_now_button != null, "Archivero deberia exponer el boton de retomar desde el perfil")
		if profile_toggle_button != null:
			profile_toggle_button.emit_signal("pressed")
			await process_frame
		if resume_now_button != null:
			_assert(resume_now_button.visible, "El boton de retomar deberia estar visible con una partida disponible")
			resume_now_button.emit_signal("pressed")
			await process_frame
			await process_frame
			_assert(current_scene != null, "Retomar desde el perfil deberia abrir una escena jugable")
			_assert(Global.current_level == 3, "Retomar desde el perfil deberia restaurar el capitulo guardado")
			if current_scene != null:
				_assert(current_scene.scene_file_path == LEVEL_SCENE, "Retomar desde el perfil deberia abrir el nivel guardado")

	if current_scene != null:
		current_scene.queue_free()
		await process_frame
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
	printerr("ARCHIVERO RESUME BUTTON TEST FAILED: %s" % message)
