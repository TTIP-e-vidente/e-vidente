extends SceneTree

const SELECTOR_SCENE := "res://niveles/selector.tscn"
const QUESTIONS_SCENE := "res://preguntas/pregunta.tscn"
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

		_assert(play_button != null, "Intro deberia seguir exponiendo el acceso principal a jugar")
		_assert(options_button != null, "Intro deberia seguir exponiendo el acceso a opciones")
		_assert(exit_button != null, "Intro deberia seguir exponiendo el acceso a salir")
		_assert(save_button == null, "Intro ya no deberia mostrar el icono de guardado en el menu principal")
		_assert(play_panel == null, "Intro ya no deberia exponer el modal intermedio para cargar partida")

		play_button.emit_signal("pressed")
		await process_frame
		await process_frame
		_assert(current_scene != null, "Jugar deberia abrir el selector de modos cuando existe un save")
		if current_scene != null:
			_assert(current_scene.scene_file_path == SELECTOR_SCENE, "Jugar deberia llevar al selector antes de retomar o cambiar de modo")
			var selector_play_panel := current_scene.get_node_or_null("PlayPanel") as PanelContainer
			var continue_button := current_scene.get_node_or_null("PlayPanel/MarginContainer/Content/ContinueButton") as Button
			var mode_button := current_scene.get_node_or_null("PlayPanel/MarginContainer/Content/ModeButton") as Button
			_assert(selector_play_panel != null, "El selector deberia exponer el panel de reanudacion cuando existe un save")
			_assert(continue_button != null, "El selector deberia exponer un boton para continuar la partida guardada")
			_assert(mode_button != null, "El selector deberia dejar elegir otro modo aunque exista un save")
			if selector_play_panel != null:
				_assert(selector_play_panel.visible, "El selector deberia mostrar el panel de reanudacion al entrar con un save")
			if continue_button != null:
				continue_button.emit_signal("pressed")
				await process_frame
				await process_frame
				_assert(Global.current_level == 3, "Continuar desde el selector deberia restaurar el capitulo guardado")
				_assert(current_scene != null, "Continuar desde el selector deberia abrir una escena jugable")
				if current_scene != null:
					_assert(current_scene.scene_file_path == LEVEL_SCENE, "Continuar desde el selector deberia abrir el nivel guardado")

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
		var fresh_play_panel: PanelContainer = fresh_intro_instance.get_node_or_null("PlayPanel")
		_assert(fresh_play_panel == null, "Sin save previo, Intro tampoco deberia reconstruir el modal de continuar")
		fresh_play_button.emit_signal("pressed")
		await process_frame
		await process_frame
		_assert(current_scene != null, "Sin partida guardada, Jugar deberia abrir el selector de modos")
		if current_scene != null:
			_assert(current_scene.scene_file_path == SELECTOR_SCENE, "Sin persistencia previa, Jugar deberia llevar al selector")
			var selector_play_panel := current_scene.get_node_or_null("PlayPanel") as PanelContainer
			var questions_button := current_scene.get_node_or_null("MenuBar/Preguntas") as Button
			_assert(selector_play_panel != null, "El selector deberia seguir exponiendo el panel auxiliar")
			_assert(questions_button != null, "El selector deberia permitir elegir el modo preguntas")
			if selector_play_panel != null:
				_assert(not selector_play_panel.visible, "Sin save previo, el selector no deberia tapar la eleccion de modo")
			if questions_button != null:
				questions_button.emit_signal("pressed")
				await process_frame
				await process_frame
				_assert(current_scene != null, "Elegir preguntas deberia abrir la escena correspondiente")
				if current_scene != null:
					_assert(current_scene.scene_file_path == QUESTIONS_SCENE, "Elegir preguntas deberia abrir la escena de preguntas")

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
	printerr("INTRO MENU SAVE TEST FAILED: %s" % message)
