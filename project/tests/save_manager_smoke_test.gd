extends SceneTree

const TEST_USERNAME := "ci_save_user"
const TEST_EMAIL := "ci_save_user@example.com"
const TEST_AGE := 24
const TEMP_AVATAR_PATH := "user://ci_avatar.png"
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

	var temp_avatar_absolute := ProjectSettings.globalize_path(TEMP_AVATAR_PATH)
	var avatar_error := _create_temp_avatar(temp_avatar_absolute)
	_assert(avatar_error == OK, "No se pudo crear el avatar temporal para la prueba")

	SaveManager.load_data()
	_assert(SaveManager.is_authenticated(), "El perfil local deberia inicializarse automaticamente")

	var profile_result: Dictionary = SaveManager.update_local_profile(
		TEST_USERNAME,
		TEST_AGE,
		TEST_EMAIL,
		temp_avatar_absolute
	)
	_assert(bool(profile_result.get("ok", false)), "Actualizacion del perfil local fallida: %s" % profile_result.get("message", "sin detalle"))
	_assert(FileAccess.file_exists(SaveManager.SAVE_PATH), "No se genero el archivo local de guardado")
	_assert(not FileAccess.file_exists(SaveManager.TEMP_SAVE_PATH), "No deberia quedar un archivo temporal luego de guardar correctamente")
	_assert(FileAccess.file_exists(STORED_AVATAR_PATH), "No se copio el avatar al almacenamiento local")
	_assert(SaveManager.get_current_user_avatar_texture() != null, "No se pudo recargar el avatar desde user://")
	var save_status: Dictionary = SaveManager.get_save_status()
	_assert(str(save_status.get("last_saved_reason", "")) == "profile_updated", "El estado del save deberia registrar que se guardo un perfil actualizado")

	var profile_scene: PackedScene = load("res://interface/auth.tscn") as PackedScene
	_assert(profile_scene != null, "No se pudo cargar la escena del perfil local")
	if profile_scene != null:
		var profile_instance: Node = profile_scene.instantiate()
		root.add_child(profile_instance)
		await process_frame
		profile_instance.queue_free()

	var archivero_scene: PackedScene = load("res://interface/archivero.tscn") as PackedScene
	_assert(archivero_scene != null, "No se pudo cargar la escena del Archivero")
	var save_status_label: Label = null
	var profile_toggle_button: Button = null
	if archivero_scene != null:
		var archivero_instance: Node = archivero_scene.instantiate()
		root.add_child(archivero_instance)
		await process_frame
		profile_toggle_button = archivero_instance.get_node("ProfileOverlayLayer/ProfileToggleButton")
		_assert(profile_toggle_button != null, "Archivero deberia exponer un boton para abrir el perfil local")
		if profile_toggle_button != null:
			profile_toggle_button.emit_signal("pressed")
			await process_frame
		save_status_label = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/StatusRow/SaveCard/MarginContainer/SaveStatusLabel")
		_assert(save_status_label != null, "Archivero deberia exponer la etiqueta de estado de guardado")
		_assert(save_status_label.text.contains("perfil actualizado"), "Archivero deberia mostrar el motivo del ultimo guardado al abrir")

		Global.items_level[1][Global.LEVEL_STATUS_INDEX] = true
		SaveManager.record_level_completed("celiaquia", 1)
		SaveManager.record_manual_save()
		await process_frame
		_assert(save_status_label.text.contains("guardado manual"), "Archivero deberia refrescar automaticamente el estado del save despues de guardar")

		Global.reset_progress()
		SaveManager.load_data()
		var progress_summary: Dictionary = Global.get_progress_summary()
		_assert(int(progress_summary.get("celiaquia", 0)) == 1, "El progreso guardado no se restauro al recargar el save local")

		archivero_instance.queue_free()

	var history: Array = SaveManager.get_current_user_history()
	_assert(history.size() >= 3, "El historial local no registro suficientes eventos del flujo smoke test")
	_assert(str(SaveManager.get_save_status().get("last_saved_reason", "")) == "load_repair" or str(SaveManager.get_save_status().get("last_saved_reason", "")) == "manual_save", "El save deberia conservar metadata del ultimo guardado")

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
	image.fill(Color(0.95, 0.74, 0.32, 1.0))
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


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("SAVE MANAGER SMOKE TEST FAILED: %s" % message)