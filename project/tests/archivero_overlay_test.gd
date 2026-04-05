extends SceneTree

const TEST_USERNAME := "overlay_user"
const TEST_EMAIL := "overlay_user@example.com"
const TEST_AGE := 21

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
	var profile_result: Dictionary = SaveManager.update_local_profile(TEST_USERNAME, TEST_AGE, TEST_EMAIL, "")
	_assert(bool(profile_result.get("ok", false)), "No se pudo preparar el perfil local para el test del overlay")

	var archivero_scene: PackedScene = load("res://interface/archivero.tscn") as PackedScene
	_assert(archivero_scene != null, "No se pudo cargar la escena del Archivero")
	if archivero_scene != null:
		var archivero_instance: Node = archivero_scene.instantiate()
		root.add_child(archivero_instance)
		await process_frame

		var profile_overlay: Control = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay")
		var profile_toggle_button: Button = archivero_instance.get_node("ProfileOverlayLayer/ProfileToggleButton")
		var close_profile_button: Button = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/CloseProfileButton")
		var history_toggle_button: Button = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/HistoryToggleButton")
		var history_panel: PanelContainer = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/HistoryPanel")
		var username_label: Label = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/InfoColumn/UsernameLabel")

		_assert(profile_overlay != null, "Archivero deberia exponer el overlay del perfil local")
		_assert(profile_toggle_button != null, "Archivero deberia exponer el boton de acceso al perfil local")
		_assert(close_profile_button != null, "Archivero deberia exponer el boton de cierre del perfil local")
		_assert(history_toggle_button != null, "Archivero deberia exponer un acceso explicito al historial")
		_assert(history_panel != null, "Archivero deberia exponer el panel de historial")
		_assert(username_label != null, "Archivero deberia exponer el label de nombre del perfil")

		_assert(not profile_overlay.visible, "El overlay del perfil deberia iniciar cerrado")
		_assert(profile_toggle_button.visible, "El boton de abrir perfil deberia iniciar visible")
		_assert(not close_profile_button.visible, "El boton de cerrar perfil no deberia verse si el overlay esta cerrado")
		_assert(not history_panel.visible, "El historial no deberia mostrarse automaticamente")

		profile_toggle_button.emit_signal("pressed")
		await process_frame

		_assert(profile_overlay.visible, "El overlay del perfil deberia abrirse al tocar el boton fijo")
		_assert(not profile_toggle_button.visible, "El boton fijo deberia ocultarse cuando el overlay esta abierto")
		_assert(close_profile_button.visible, "El boton de cierre deberia verse cuando el overlay esta abierto")
		_assert(username_label.text.contains(TEST_USERNAME), "El overlay abierto deberia mostrar el nombre del perfil local preparado")
		history_toggle_button.emit_signal("pressed")
		await process_frame
		_assert(history_panel.visible, "El historial deberia abrirse solo al tocar el boton correspondiente")
		history_toggle_button.emit_signal("pressed")
		await process_frame
		_assert(not history_panel.visible, "El historial deberia poder ocultarse nuevamente desde el mismo boton")

		var close_by_backdrop := InputEventMouseButton.new()
		close_by_backdrop.button_index = MOUSE_BUTTON_LEFT
		close_by_backdrop.pressed = true
		archivero_instance.call("_on_profile_backdrop_gui_input", close_by_backdrop)
		await process_frame

		_assert(not profile_overlay.visible, "El overlay del perfil deberia cerrarse al tocar el fondo")
		_assert(profile_toggle_button.visible, "El boton fijo deberia volver a mostrarse al cerrar el overlay")

		profile_toggle_button.emit_signal("pressed")
		await process_frame
		close_profile_button.emit_signal("pressed")
		await process_frame

		_assert(not profile_overlay.visible, "El overlay del perfil deberia cerrarse con el boton de cierre")
		_assert(profile_toggle_button.visible, "El boton fijo deberia quedar visible despues de cerrar con el boton de cierre")

		archivero_instance.queue_free()

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
	printerr("ARCHIVERO OVERLAY TEST FAILED: %s" % message)