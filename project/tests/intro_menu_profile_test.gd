extends SceneTree

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
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
		var save_button: Button = intro_instance.get_node("SaveButton")
		var save_feedback_label: Label = intro_instance.get_node("SaveFeedbackLabel")
		var play_panel: PanelContainer = intro_instance.get_node("PlayPanel")
		var play_panel_subtitle: Label = intro_instance.get_node("PlayPanel/MarginContainer/Content/Subtitle")
		var new_game_button: Button = intro_instance.get_node("PlayPanel/MarginContainer/Content/NewGameButton")
		var load_game_button: Button = intro_instance.get_node("PlayPanel/MarginContainer/Content/LoadGameButton")
		var close_play_panel_button: Button = intro_instance.get_node("PlayPanel/MarginContainer/Content/ClosePlayPanelButton")

		_assert(play_button != null, "Intro deberia seguir exponiendo el acceso principal a jugar")
		_assert(options_button != null, "Intro deberia seguir exponiendo el acceso a opciones")
		_assert(exit_button != null, "Intro deberia seguir exponiendo el acceso a salir")
		_assert(save_button != null, "Intro deberia exponer un acceso simple al guardado de partida")
		_assert(save_feedback_label != null, "Intro deberia mostrar feedback del guardado rapido")
		_assert(play_panel != null, "Intro deberia exponer un panel simple para cargar partida")
		_assert(play_panel_subtitle != null, "Intro deberia mostrar desde donde se retomara la partida")
		_assert(new_game_button != null, "Intro deberia exponer la accion de nueva partida al tocar Jugar")
		_assert(load_game_button != null, "Intro deberia exponer la accion de cargar partida al tocar Jugar")
		_assert(close_play_panel_button != null, "Intro deberia permitir cerrar el panel de carga")

		_assert(save_button.tooltip_text.contains("guardado de partida"), "El acceso superior deberia aclarar que corresponde al guardado")
		_assert(save_button.tooltip_text.contains("Celiaquia"), "El acceso superior deberia anticipar desde donde se retoma la partida")
		_assert(not play_panel.visible, "El panel de carga deberia iniciar oculto")

		save_button.emit_signal("pressed")
		await process_frame
		_assert(FileAccess.file_exists(SaveManager.SAVE_PATH), "El acceso de guardado del menu deberia escribir el save principal")
		_assert(str(SaveManager.get_save_status().get("last_saved_reason", "")) == "manual_save", "El guardado desde Intro deberia registrarse como guardado manual")
		_assert(save_feedback_label.text.contains("guardado"), "Intro deberia confirmar visualmente el guardado")

		play_button.emit_signal("pressed")
		await process_frame
		_assert(play_panel.visible, "Al tocar Jugar deberia abrirse el panel con la opcion de cargar partida")
		_assert(play_panel_subtitle.text.contains("Celiaquia"), "El panel deberia explicar desde que libro se retomara")
		_assert(play_panel_subtitle.text.contains("3"), "El panel deberia explicar desde que capitulo se retomara")
		_assert(new_game_button.text.contains("Nueva partida"), "La accion de juego deberia permitir iniciar una nueva partida")
		_assert(load_game_button.text.contains("Cargar partida"), "La accion de juego deberia nombrar la carga de partida")
		_assert(not load_game_button.disabled, "Cuando existe un punto de guardado la accion de cargar deberia quedar habilitada")

		new_game_button.emit_signal("pressed")
		await process_frame
		_assert(new_game_button.text.contains("Confirmar"), "Si ya existe una partida, Nueva partida deberia pedir confirmacion antes de resetear el save")
		_assert(save_feedback_label.text.contains("reemplaza"), "La confirmacion de nueva partida deberia advertir que se reemplaza la partida actual")
		_assert(str(SaveManager.get_save_status().get("last_saved_reason", "")) == "manual_save", "El primer toque sobre Nueva partida no deberia sobrescribir el save existente")

		close_play_panel_button.emit_signal("pressed")
		await process_frame
		_assert(not play_panel.visible, "El panel de carga deberia cerrarse al cancelar")
		_assert(new_game_button.text.contains("Nueva partida"), "Cerrar el panel deberia limpiar la confirmacion pendiente de nueva partida")

		play_button.emit_signal("pressed")
		await process_frame

		load_game_button.emit_signal("pressed")
		await process_frame
		await process_frame
		_assert(Global.current_level == 3, "Cargar partida deberia restaurar el capitulo guardado para retomar")
		_assert(current_scene != null, "Cargar partida deberia abrir una escena jugable")
		if current_scene != null:
			_assert(current_scene.scene_file_path == "res://niveles/nivel_1/Level.tscn", "Cargar partida deberia abrir el nivel guardado en vez de volver al Archivero")

	_cleanup_test_files()
	await process_frame
	quit(1 if failed else 0)


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