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

	var keto_scene: PackedScene = load("res://interface/Libro-Keto.tscn") as PackedScene
	_assert(keto_scene != null, "No se pudo cargar el libro de keto")
	if keto_scene != null:
		var keto_instance: Node = keto_scene.instantiate()
		root.add_child(keto_instance)
		await process_frame
		var chapter_container := keto_instance.get_node_or_null("VBoxContainer") as VBoxContainer
		_assert(chapter_container != null, "El libro de keto deberia exponer el contenedor de capitulos")
		if chapter_container != null:
			_assert(chapter_container.get_child_count() == Global.get_track_level_count("cetogenica"), "El libro de keto deberia reconstruir los capitulos segun el catalogo del track")

		var cap_1 := keto_instance.get_node_or_null("VBoxContainer/Cap1") as Button
		_assert(cap_1 != null, "El libro de keto deberia exponer el acceso al capitulo 1")
		if cap_1 != null:
			cap_1.emit_signal("pressed")
			await process_frame
			await process_frame
			_assert(Global.current_level == 1, "Capitulo 1 de keto deberia fijar el nivel actual en 1")
			_assert(current_scene != null, "Capitulo 1 de keto deberia abrir una escena jugable")
			if current_scene != null:
				_assert(current_scene.scene_file_path == "res://niveles/nivel_4/Level-Keto.tscn", "Capitulo 1 de keto deberia abrir el nivel de keto")
				var manager_level = current_scene.get_node_or_null("ManagerLevel")
				var expected_run: Dictionary = Global.get_chapter_run_definition("cetogenica", 1, 1)
				_assert(manager_level != null, "El nivel de keto deberia exponer el ManagerLevel")
				_assert(not expected_run.is_empty(), "Keto deberia resolver su corrida inicial desde el catalogo")
				if manager_level != null and not expected_run.is_empty():
					_assert(manager_level.current_track_key == "cetogenica", "Capitulo 1 de keto deberia configurar ManagerLevel con el track correcto")
					_assert(manager_level.current_run_data == expected_run, "Capitulo 1 de keto deberia cargar la corrida definida para cetogenica en el catalogo")
					_assert(int(manager_level.get_total_runs()) == 1, "La integracion actual de keto deberia exponer una unica corrida por capitulo")

		if current_scene != null:
			current_scene.queue_free()
			await process_frame
		elif is_instance_valid(keto_instance):
			keto_instance.queue_free()
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
	printerr("KETO BOOK TEST FAILED: %s" % message)
