extends SceneTree

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

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

	for track_definition in GameTrackCatalog.get_track_definitions():
		_cleanup_test_files()
		await process_frame
		await _run_track_case(track_definition)
		if failed:
			break

	_cleanup_test_files()
	await process_frame
	quit(1 if failed else 0)


func _run_track_case(track_definition: Dictionary) -> void:
	var track_key := str(track_definition.get("key", "")).strip_edges()
	var book_scene_path := str(track_definition.get("book_scene_path", "")).strip_edges()
	var level_scene_path := str(track_definition.get("level_scene_path", "")).strip_edges()
	var expected_level_count: int = int(Global.get_track_level_count(track_key))
	var case_label := "%s (%s)" % [track_key, book_scene_path]
	print("TRACK BOOK TEST TRACE: start %s" % case_label)

	var book_scene: PackedScene = load(book_scene_path) as PackedScene
	_assert(book_scene != null, "No se pudo cargar la escena de libro %s" % case_label)
	if book_scene == null:
		return

	var book_instance: Node = book_scene.instantiate()
	_assert(book_instance != null, "No se pudo instanciar la escena de libro %s" % case_label)
	if book_instance == null:
		return
	root.add_child(book_instance)
	await process_frame

	var chapter_container := book_instance.get_node_or_null("VBoxContainer") as VBoxContainer
	_assert(chapter_container != null, "%s deberia exponer el contenedor de capitulos" % case_label)
	if chapter_container != null:
		_assert(chapter_container.get_child_count() == expected_level_count, "%s deberia reconstruir sus capitulos segun el catalogo del track" % case_label)

	var first_chapter_button := book_instance.get_node_or_null("VBoxContainer/Cap1") as Button
	var last_chapter_button := book_instance.get_node_or_null("VBoxContainer/Cap%d" % expected_level_count) as Button
	_assert(first_chapter_button != null, "%s deberia exponer el acceso al capitulo 1" % case_label)
	_assert(last_chapter_button != null, "%s deberia exponer el acceso al ultimo capitulo catalogado" % case_label)
	if first_chapter_button != null:
		_assert(not first_chapter_button.disabled, "%s deberia dejar desbloqueado el capitulo 1" % case_label)
		first_chapter_button.emit_signal("pressed")
		await process_frame
		await process_frame
		_assert(Global.current_level == 1, "%s deberia fijar el nivel actual en 1 al abrir el primer capitulo" % case_label)
		_assert(current_scene != null, "%s deberia abrir una escena jugable" % case_label)
		if current_scene != null:
			_assert(current_scene.scene_file_path == level_scene_path, "%s deberia abrir la escena jugable del track" % case_label)
			_assert(current_scene.has_method("_get_resume_track_key"), "%s deberia exponer el track del nivel actual" % level_scene_path)
			if current_scene.has_method("_get_resume_track_key"):
				_assert(str(current_scene._get_resume_track_key()) == track_key, "%s deberia estar alineado con el track %s" % [level_scene_path, track_key])
			var manager_level = current_scene.get_node_or_null("ManagerLevel")
			var expected_run: Dictionary = Global.get_chapter_run_definition(track_key, 1, 1)
			_assert(manager_level != null, "%s deberia exponer el ManagerLevel" % level_scene_path)
			_assert(not expected_run.is_empty(), "%s deberia resolver la corrida inicial desde el catalogo" % case_label)
			if manager_level != null and not expected_run.is_empty():
				_assert(manager_level.active_track_key == track_key, "%s deberia configurar ManagerLevel con el track correcto" % case_label)
				_assert(manager_level.active_run_data == expected_run, "%s deberia cargar la corrida inicial definida en el catalogo" % case_label)
				_assert(int(manager_level.get_total_runs()) == Global.get_chapter_run_count(track_key, 1), "%s deberia exponer la cantidad real de corridas del capitulo" % case_label)

	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	if is_instance_valid(book_instance):
		book_instance.queue_free()
		await process_frame


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
	printerr("TRACK BOOK TEST FAILED: %s" % message)
