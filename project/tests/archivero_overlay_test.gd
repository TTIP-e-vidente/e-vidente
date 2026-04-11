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
	Global.mark_level_completed("celiaquia", 1)
	Global.mark_level_completed("celiaquia", 2)
	Global.mark_level_completed("veganismo", 1)
	SaveManager.set_resume_to_level("celiaquia", 3)
	SaveManager.record_manual_save()

	var archivero_scene: PackedScene = load("res://interface/archivero.tscn") as PackedScene
	_assert(archivero_scene != null, "No se pudo cargar la escena del Archivero")
	if archivero_scene != null:
		var archivero_instance: Node = archivero_scene.instantiate()
		root.add_child(archivero_instance)
		await process_frame

		var archivero_container: VBoxContainer = archivero_instance.get_node("CanvasLayer/ArchiveroContainer")
		var profile_overlay: Control = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay")
		var profile_toggle_button: Button = archivero_instance.get_node("ProfileOverlayLayer/ProfileToggleButton")
		var close_profile_button: Button = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/CloseProfileButton")
		var history_toggle_button: Button = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SecondaryActionsRow/HistoryToggleButton")
		var reset_progress_button: Button = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SecondaryActionsRow/ResetProgressButton")
		var reset_progress_dialog: ConfirmationDialog = archivero_instance.get_node("ResetProgressDialog")
		var history_panel: PanelContainer = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/HistoryPanel")
		var username_label: Label = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/InfoColumn/UsernameLabel")
		var progress_label: Label = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/InfoColumn/ProgressPanel/MarginContainer/ProgressLabel")
		var resume_hint_label: Label = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/StatusRow/ResumeCard/MarginContainer/ResumeContent/ResumeHintLabel")
		var resume_now_button: Button = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/StatusRow/ResumeCard/MarginContainer/ResumeContent/ResumeNowButton")
		var save_status_label: Label = archivero_instance.get_node("ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/StatusRow/SaveCard/MarginContainer/SaveStatusLabel")

		_assert(archivero_container != null, "Archivero deberia exponer el contenedor de modos")
		_assert(profile_overlay != null, "Archivero deberia exponer el overlay del perfil local")
		_assert(profile_toggle_button != null, "Archivero deberia exponer el boton de acceso al perfil local")
		_assert(close_profile_button != null, "Archivero deberia exponer el boton de cierre del perfil local")
		_assert(history_toggle_button != null, "Archivero deberia exponer un acceso explicito al historial")
		_assert(reset_progress_button != null, "Archivero deberia exponer un boton para reiniciar el progreso")
		_assert(reset_progress_dialog != null, "Archivero deberia exponer un dialogo de confirmacion para reiniciar el progreso")
		_assert(history_panel != null, "Archivero deberia exponer el panel de historial")
		_assert(username_label != null, "Archivero deberia exponer el label de nombre del perfil")
		_assert(progress_label != null, "Archivero deberia exponer el resumen textual del progreso")
		_assert(resume_hint_label != null, "Archivero deberia exponer el resumen de reanudacion")
		_assert(resume_now_button != null, "Archivero deberia exponer un boton para retomar la partida desde el perfil")
		_assert(save_status_label != null, "Archivero deberia exponer el label del estado de guardado")
		_assert(archivero_container.get_child_count() == Global.get_track_definitions().size(), "Archivero deberia construir una tarjeta por cada track definido en el catalogo")

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
		_assert(progress_label.text.contains("Celiaquia 3/6"), "El resumen deberia mostrar el siguiente capitulo disponible para celiaquia")
		_assert(progress_label.text.contains("Veganismo 2/6"), "El resumen deberia mostrar el siguiente capitulo disponible para veganismo")
		_assert(resume_hint_label.text.contains("Retoma en Celiaquia capitulo 3"), "El perfil deberia resumir el punto exacto de reanudacion")
		_assert(resume_now_button.visible, "El boton de retomar deberia mostrarse cuando hay una partida disponible")
		history_toggle_button.emit_signal("pressed")
		await process_frame
		_assert(history_panel.visible, "El historial deberia abrirse solo al tocar el boton correspondiente")
		history_toggle_button.emit_signal("pressed")
		await process_frame
		_assert(not history_panel.visible, "El historial deberia poder ocultarse nuevamente desde el mismo boton")
		reset_progress_button.emit_signal("pressed")
		await process_frame
		_assert(reset_progress_dialog.visible, "El reinicio del progreso deberia pedir confirmacion explicita")
		reset_progress_dialog.emit_signal("confirmed")
		await process_frame
		_assert(int(Global.get_progress_summary().get("total", -1)) == 0, "Confirmar el reinicio deberia limpiar el progreso jugable")
		_assert(not SaveManager.can_resume_game(), "Confirmar el reinicio no deberia dejar una partida retomable")
		_assert(save_status_label.text.contains("progreso reiniciado"), "El overlay deberia reflejar que el ultimo guardado fue un reinicio del progreso")

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
