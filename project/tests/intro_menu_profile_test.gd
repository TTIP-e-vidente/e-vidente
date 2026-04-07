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

	SaveManager.load_data()
	Global.current_level = 3
	SaveManager.set_resume_to_level("celiaquia", Global.current_level)
	SaveManager.record_manual_save()
	var intro_scene: PackedScene = load("res://niveles/intro.tscn") as PackedScene
	_assert(intro_scene != null, "No se pudo cargar la escena Intro")
	if intro_scene != null:
		var intro_instance: Node = intro_scene.instantiate()
		root.add_child(intro_instance)
		await process_frame

		var play_button: Button = intro_instance.get_node("MenuBar/Jugar")
		var options_button: Button = intro_instance.get_node("MenuBar/Opciones")
		var exit_button: Button = intro_instance.get_node("MenuBar/Salir")
		var save_button: Node = intro_instance.get_node_or_null("SaveButton")
		var play_panel: PanelContainer = intro_instance.get_node_or_null("PlayPanel")
		var continue_button: Button = intro_instance.get_node_or_null("PlayPanel/MarginContainer/Content/ContinueButton")
		var mode_button: Button = intro_instance.get_node_or_null("PlayPanel/MarginContainer/Content/ModeButton")

		_assert(play_button != null, "Intro deberia seguir exponiendo el acceso principal a jugar")
		_assert(options_button != null, "Intro deberia seguir exponiendo el acceso a opciones")
		_assert(exit_button != null, "Intro deberia seguir exponiendo el acceso a salir")
		_assert(save_button == null, "Intro ya no deberia mostrar el icono de guardado en el menu principal")
		_assert(play_panel != null, "Intro deberia exponer un panel minimo para seguir jugando")
		_assert(continue_button != null, "Intro deberia exponer el acceso para continuar la ultima partida")
		_assert(mode_button != null, "Intro deberia exponer una salida clara al selector de modos")
		_assert(not play_panel.visible, "El panel minimo deberia iniciar cerrado")

		play_button.emit_signal("pressed")
		await process_frame
		_assert(play_panel.visible, "Jugar deberia abrir el panel minimo antes de cambiar de escena")
		_assert(continue_button.visible, "Con una partida guardada deberia verse la opcion de continuar")
		continue_button.emit_signal("pressed")
		await process_frame
		await process_frame
		_assert(Global.current_level == 3, "Cargar partida deberia restaurar el capitulo guardado para retomar")
		_assert(current_scene != null, "Cargar partida deberia abrir una escena jugable")
		if current_scene != null:
			_assert(current_scene.scene_file_path == "res://niveles/nivel_1/Level.tscn", "Cargar partida deberia abrir el nivel guardado en vez de volver al Archivero")
			current_scene.call("_on_atrás_pressed")
			await process_frame
			await process_frame
			_assert(current_scene != null, "Volver atras desde el nivel deberia abrir el libro correspondiente")
			if current_scene != null:
				_assert(current_scene.scene_file_path == "res://interface/libro.tscn", "Volver atras desde el nivel cargado deberia abrir su libro")
				var chapter_container: VBoxContainer = current_scene.get_node("VBoxContainer")
				_assert(chapter_container.get_child_count() == Global.get_track_level_count("celiaquia"), "El libro deberia generar sus capitulos segun la cantidad definida para el track")
				current_scene.call("_on_button_pressed")
				await process_frame
				await process_frame
				_assert(current_scene != null, "Desde el libro deberia poder volver al selector de modos")
				if current_scene != null:
					_assert(current_scene.scene_file_path == "res://interface/archivero.tscn", "Desde una partida cargada deberia poder volver al selector de modos")

		_cleanup_test_files()
		await process_frame
		if current_scene != null:
			current_scene.queue_free()
			await process_frame
		if is_instance_valid(intro_instance):
			intro_instance.queue_free()
			await process_frame

		var fresh_intro_instance: Node = intro_scene.instantiate()
		root.add_child(fresh_intro_instance)
		await process_frame
		var fresh_play_button: Button = fresh_intro_instance.get_node("MenuBar/Jugar")
		var fresh_play_panel: PanelContainer = fresh_intro_instance.get_node("PlayPanel")
		var fresh_continue_button: Button = fresh_intro_instance.get_node("PlayPanel/MarginContainer/Content/ContinueButton")
		var fresh_mode_button: Button = fresh_intro_instance.get_node("PlayPanel/MarginContainer/Content/ModeButton")
		fresh_play_button.emit_signal("pressed")
		await process_frame
		_assert(fresh_play_panel.visible, "Sin save previo, Jugar deberia abrir el panel minimo")
		_assert(not fresh_continue_button.visible, "Sin save previo no deberia verse la opcion de continuar")
		_assert(fresh_mode_button.text.contains("Empezar"), "Sin save previo la accion secundaria deberia invitar a empezar")
		fresh_mode_button.emit_signal("pressed")
		await process_frame
		await process_frame
		_assert(current_scene != null, "Sin partida guardada, Jugar deberia abrir el selector de modos")
		if current_scene != null:
			_assert(current_scene.scene_file_path == "res://interface/archivero.tscn", "Sin persistencia previa, Jugar deberia llevar directo al Archivero")

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
	printerr("INTRO MENU SAVE TEST FAILED: %s" % message)