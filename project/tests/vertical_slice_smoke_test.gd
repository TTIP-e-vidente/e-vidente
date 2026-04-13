extends SceneTree

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

const INTRO_SCENE := "res://niveles/intro.tscn"
const SELECTOR_SCENE := "res://niveles/selector.tscn"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const BASELINE_TRACK_KEY := "celiaquia"

var save_manager
var global_state
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_resolve_singletons()
	_assert(save_manager != null, "No se encontro el autoload SaveManager")
	_assert(global_state != null, "No se encontro el autoload Global")
	if failed:
		quit(1)
		return

	_cleanup_test_files()
	await process_frame

	var track_definitions: Array = global_state.get_track_definitions()
	_assert(not track_definitions.is_empty(), "No hay tracks disponibles para el smoke test")
	if track_definitions.is_empty():
		_cleanup_and_quit()
		return

	var baseline_book_scene_path := global_state.get_book_scene_path(BASELINE_TRACK_KEY)
	var baseline_level_scene_path := global_state.get_level_scene_path(BASELINE_TRACK_KEY)
	_assert(
		not baseline_book_scene_path.is_empty(),
		"El track baseline no resolvio escena de libro"
	)
	_assert(
		not baseline_level_scene_path.is_empty(),
		"El track baseline no resolvio escena jugable"
	)
	if baseline_book_scene_path.is_empty() or baseline_level_scene_path.is_empty():
		_cleanup_and_quit()
		return

	var intro_error := change_scene_to_file(INTRO_SCENE)
	_assert(intro_error == OK, "No se pudo abrir la escena Intro")
	await _wait_for_scene_path(INTRO_SCENE, "Intro")
	if failed:
		_cleanup_and_quit()
		return

	var play_button := current_scene.get_node_or_null("MenuBar/Jugar") as Button
	_assert(play_button != null, "Intro deberia exponer el acceso principal a jugar")
	if play_button == null:
		_cleanup_and_quit()
		return

	play_button.emit_signal("pressed")
	await _wait_for_scene_path(SELECTOR_SCENE, "Selector")
	if failed:
		_cleanup_and_quit()
		return

	var recipes_button := current_scene.get_node_or_null("MenuBar/Recetas") as Button
	_assert(recipes_button != null, "Selector deberia exponer el acceso a Recetas")
	if recipes_button == null:
		_cleanup_and_quit()
		return

	recipes_button.emit_signal("pressed")
	await _wait_for_scene_path(ARCHIVERO_SCENE, "Archivero")
	if failed:
		_cleanup_and_quit()
		return

	await process_frame
	var track_container := current_scene.get_node_or_null(
		"CanvasLayer/ArchiveroContainer"
	) as VBoxContainer
	_assert(track_container != null, "Archivero deberia exponer el contenedor de tracks")
	if track_container == null:
		_cleanup_and_quit()
		return

	var track_card_count := _count_track_cards(track_container)
	_assert(
		track_card_count >= 1,
		"Archivero deberia reconstruir al menos un track"
	)
	_assert(
		track_card_count == track_definitions.size(),
		"Archivero deberia reconstruir todos los tracks del catalogo"
	)
	_assert(
		track_container.get_node_or_null("Track_%s" % BASELINE_TRACK_KEY) != null,
		"Archivero deberia exponer la card del track baseline"
	)

	GameSceneRouter.go_to_track_book(self, BASELINE_TRACK_KEY)
	await _wait_for_scene_path(
		baseline_book_scene_path,
		"Libro del track"
	)
	if failed:
		_cleanup_and_quit()
		return

	var first_chapter_button := current_scene.get_node_or_null(
		"VBoxContainer/Cap1"
	) as Button
	_assert(
		first_chapter_button != null,
		"El libro deberia exponer el acceso al capitulo 1"
	)
	if first_chapter_button == null:
		_cleanup_and_quit()
		return

	_assert(
		not first_chapter_button.disabled,
		"El capitulo 1 deberia estar disponible en el smoke test"
	)
	first_chapter_button.emit_signal("pressed")
	await _wait_for_scene_path(
		baseline_level_scene_path,
		"Gameplay"
	)
	if failed:
		_cleanup_and_quit()
		return

	var manager_level = current_scene.get_node_or_null("ManagerLevel")
	var plate = current_scene.get_node_or_null("Plato")
	var meal_sprite = current_scene.get_node_or_null("Globo texto/Meal")
	var condition_sprite = current_scene.get_node_or_null("Globo texto/Condition")

	_assert(manager_level != null, "La escena jugable deberia exponer ManagerLevel")
	_assert(plate != null, "La escena jugable deberia exponer el Plato")
	_assert(meal_sprite != null, "La escena jugable deberia exponer el nodo Meal")
	_assert(
		condition_sprite != null,
		"La escena jugable deberia exponer el nodo Condition"
	)
	if manager_level != null:
		_assert(
			str(manager_level.active_track_key) == BASELINE_TRACK_KEY,
			"ManagerLevel deberia inicializarse con el track seleccionado"
		)
		_assert(
			not (manager_level.active_run_data as Dictionary).is_empty(),
			"ManagerLevel deberia cargar una corrida valida al entrar al gameplay"
		)
		_assert(
			int(manager_level.get_current_run_index()) == 1,
			"El smoke test deberia entrar en la primera corrida"
		)
		_assert(
			int(manager_level.get_total_runs()) >= 1,
			"El gameplay deberia exponer al menos una corrida jugable"
		)

	_assert(
		int(global_state.get_current_level_number()) == 1,
		"Global deberia registrar el capitulo abierto"
	)

	await process_frame
	await process_frame
	_assert(
		is_instance_valid(current_scene),
		"La escena jugable no deberia crashear en los primeros frames"
	)

	_cleanup_and_quit()


func _count_track_cards(track_container: VBoxContainer) -> int:
	var count := 0
	for child in track_container.get_children():
		if String(child.name).begins_with("Track_"):
			count += 1
	return count


func _wait_for_scene_path(expected_path: String, label: String) -> void:
	for frame_index in range(8):
		_ = frame_index
		await process_frame
		if current_scene != null and current_scene.scene_file_path == expected_path:
			return
	_assert(false, "No se pudo llegar a %s (%s)" % [label, expected_path])


func _resolve_singletons() -> void:
	if save_manager == null:
		save_manager = root.get_node_or_null("/root/SaveManager")
	if global_state == null:
		global_state = root.get_node_or_null("/root/Global")


func _cleanup_test_files() -> void:
	global_state.reset_progress()
	for relative_path in [
		save_manager.SAVE_PATH,
		save_manager.TEMP_SAVE_PATH,
		save_manager.BACKUP_SAVE_PATH
	]:
		var absolute_path := ProjectSettings.globalize_path(relative_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	save_manager.load_data()


func _cleanup_and_quit() -> void:
	_cleanup_test_files()
	quit(1 if failed else 0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("VERTICAL SLICE SMOKE TEST FAILED: %s" % message)