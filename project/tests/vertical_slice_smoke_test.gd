extends SceneTree

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameChapterAssetCatalogScript := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const SPLASH_SCENE := "res://interface/evidente.tscn"
const INTRO_SCENE := "res://niveles/intro.tscn"
const SELECTOR_SCENE := "res://niveles/selector.tscn"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const BASELINE_TRACK_KEY := "celiaquia"
const MANAGER_LEVEL_NODE_PATH := "ManagerLevel"
const PLATE_NODE_PATH := "Plato"
const MEAL_NODE_PATH := "Globo texto/Meal"
const CONDITION_NODE_PATH := "Globo texto/Condition"

var save_manager
var global_state
var failed := false
var _baseline_book_scene_path := ""
var _baseline_level_scene_path := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	if not await _prepare_test_runtime():
		await _cleanup_and_quit()
		return

	if not await _enter_gameplay_scene():
		await _cleanup_and_quit()
		return

	_assert_gameplay_scene_contract()
	if not failed:
		await _assert_gameplay_scene_stays_alive()

	await _cleanup_and_quit()


func _prepare_test_runtime() -> bool:
	_resolve_singletons()
	_assert(save_manager != null, "No se encontro el autoload SaveManager")
	_assert(global_state != null, "No se encontro el autoload Global")
	if failed:
		return false

	_cleanup_test_files()
	await process_frame
	return _resolve_baseline_track_scene_paths()


func _resolve_baseline_track_scene_paths() -> bool:
	var baseline_track_definition: Dictionary = GameTrackCatalog.get_track_definition(BASELINE_TRACK_KEY)
	_assert(not baseline_track_definition.is_empty(), "No hay track baseline disponible para el smoke test")
	if baseline_track_definition.is_empty():
		return false

	_baseline_book_scene_path = str(baseline_track_definition.get("book_scene_path", "")).strip_edges()
	_baseline_level_scene_path = str(baseline_track_definition.get("level_scene_path", "")).strip_edges()
	_assert(not _baseline_book_scene_path.is_empty(), "El track baseline no resolvio escena de libro")
	_assert(not _baseline_level_scene_path.is_empty(), "El track baseline no resolvio escena jugable")
	return not failed


func _enter_gameplay_scene() -> bool:
	if not await _open_scene(SPLASH_SCENE, "Splash"):
		return false

	if not await _invoke_current_scene_method_and_wait(
		"_on_go_pressed",
		[],
		INTRO_SCENE,
		"Intro",
		"Splash deberia exponer el avance al menu principal"
	):
		return false

	if not await _invoke_current_scene_method_and_wait(
		"_on_start_pressed",
		[],
		SELECTOR_SCENE,
		"Selector",
		"Intro deberia exponer el acceso principal a jugar"
	):
		return false

	if not await _invoke_current_scene_method_and_wait(
		"_on_start_pressed",
		[],
		ARCHIVERO_SCENE,
		"Archivero",
		"Selector deberia exponer el acceso al flujo principal"
	):
		return false

	await process_frame
	_assert(is_instance_valid(current_scene), "Archivero no deberia crashear al abrirse")
	if failed:
		return false

	GameSceneRouter.go_to_track_book(self, BASELINE_TRACK_KEY)
	await _wait_for_scene_path(_baseline_book_scene_path, "Libro del track")
	if failed:
		return false

	return await _invoke_current_scene_method_and_wait(
		"_open_track_chapter",
		[1],
		_baseline_level_scene_path,
		"Gameplay",
		"El libro deberia exponer una forma publica de abrir un capitulo"
	)


func _open_scene(scene_path: String, scene_label: String) -> bool:
	var open_error := change_scene_to_file(scene_path)
	_assert(open_error == OK, "No se pudo abrir la escena %s" % scene_label)
	if failed:
		return false
	await _wait_for_scene_path(scene_path, scene_label)
	return not failed


func _invoke_current_scene_method_and_wait(
	method_name: String,
	method_arguments: Array,
	expected_scene_path: String,
	expected_scene_label: String,
	missing_method_message: String
) -> bool:
	_assert(current_scene != null, "No hay escena actual antes de avanzar a %s" % expected_scene_label)
	if failed:
		return false
	_assert(current_scene.has_method(method_name), missing_method_message)
	if failed:
		return false
	current_scene.callv(method_name, method_arguments)
	await _wait_for_scene_path(expected_scene_path, expected_scene_label)
	return not failed


func _assert_gameplay_scene_contract() -> void:
	var manager_level = current_scene.get_node_or_null(MANAGER_LEVEL_NODE_PATH)
	var plate = current_scene.get_node_or_null(PLATE_NODE_PATH)
	var meal_sprite: Sprite2D = current_scene.get_node_or_null(MEAL_NODE_PATH) as Sprite2D
	var condition_sprite: Sprite2D = current_scene.get_node_or_null(CONDITION_NODE_PATH) as Sprite2D

	_assert(manager_level != null, "La escena jugable deberia exponer ManagerLevel")
	_assert(plate != null, "La escena jugable deberia exponer el Plato")
	_assert(meal_sprite != null, "La escena jugable deberia exponer el nodo Meal")
	_assert(condition_sprite != null, "La escena jugable deberia exponer el nodo Condition")
	if manager_level == null:
		return
	_assert(
		manager_level.has_method("get_current_run_index"),
		"ManagerLevel deberia cargar su script runtime"
	)
	_assert(
		manager_level.has_method("get_total_runs"),
		"ManagerLevel deberia exponer el contrato publico del gameplay"
	)
	var raw_active_track_key: Variant = manager_level.get("active_track_key")
	var raw_active_run_data: Variant = manager_level.get("active_run_data")
	var active_run_data: Dictionary = (
		raw_active_run_data if raw_active_run_data is Dictionary else {}
	)

	_assert(
		str(raw_active_track_key) == BASELINE_TRACK_KEY,
		"ManagerLevel deberia inicializarse con el track seleccionado"
	)
	_assert(
		not active_run_data.is_empty(),
		"ManagerLevel deberia cargar una corrida valida al entrar al gameplay"
	)
	_assert(
		int(manager_level.call("get_current_run_index")) == 1,
		"El smoke test deberia entrar en la primera corrida"
	)
	_assert(
		int(manager_level.call("get_total_runs")) >= 1,
		"El gameplay deberia exponer al menos una corrida jugable"
	)
	_assert(
		int(global_state.get_current_level_number()) == 1,
		"Global deberia registrar el capitulo abierto"
	)


func _assert_gameplay_scene_stays_alive() -> void:
	await process_frame
	await process_frame
	await process_frame
	_assert(is_instance_valid(current_scene), "La escena jugable no deberia crashear en los primeros frames")


func _wait_for_scene_path(expected_path: String, label: String) -> void:
	for _frame_index in range(12):
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
	if global_state != null:
		global_state.reset_progress()
		global_state.is_dragging = null
		global_state.player_cambiante = null
		global_state.manager_level = null
	if save_manager == null:
		return
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
	_stop_runtime_audio()
	_release_loaded_scene()
	_cleanup_test_files()
	GameChapterAssetCatalogScript.clear_texture_cache()
	save_manager = null
	global_state = null
	await process_frame
	await process_frame
	quit(1 if failed else 0)


func _release_loaded_scene() -> void:
	if not is_instance_valid(current_scene):
		return
	var loaded_scene: Node = current_scene
	current_scene = null
	loaded_scene.free()


func _stop_runtime_audio() -> void:
	for audio_player in root.find_children("*", "AudioStreamPlayer", true, false):
		var player: AudioStreamPlayer = audio_player as AudioStreamPlayer
		if player == null:
			continue
		player.stop()
		player.stream = null
	for audio_player in root.find_children("*", "AudioStreamPlayer2D", true, false):
		var player: AudioStreamPlayer2D = audio_player as AudioStreamPlayer2D
		if player == null:
			continue
		player.stop()
		player.stream = null


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("VERTICAL SLICE SMOKE TEST FAILED: %s" % message)