extends SceneTree

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameChapterAssetCatalog := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)

const BOOK_SCENE := "res://interface/libro.tscn"
const LEVEL_SCENE := "res://niveles/nivel_1/Level.tscn"

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var global = root.get_node_or_null("/root/Global")
	var save_mgr = root.get_node_or_null("/root/SaveManager")
	_check(global != null, "Autoload Global no encontrado")
	_check(save_mgr != null, "Autoload SaveManager no encontrado")
	if failed:
		await _quit()
		return

	# Limpiar estado de test
	global.reset_progress()
	Item_level.is_dragging = null
	_delete_save_files(save_mgr)
	save_mgr.load_data()
	await process_frame


	await _go_to("res://interface/evidente.tscn", "Splash")
	await _call_and_expect("_on_go_pressed", "res://niveles/intro.tscn", "Intro")
	await _call_and_expect("_on_start_pressed", "res://niveles/selector.tscn", "Selector")
	await _call_and_expect("_on_start_pressed", "res://interface/archivero.tscn", "Archivero")

	if not failed:
		GameSceneRouter.go_to_track_book(self, "celiaquia")
		await _wait_for(BOOK_SCENE, "Libro")

	if not failed:
		await _call_and_expect("_open_track_chapter", LEVEL_SCENE, "Nivel", [1])


	if not failed:
		_check_gameplay_scene(global)


	if not failed:
		for i in 3:
			await process_frame
		_check(is_instance_valid(current_scene), "La escena crasheo en los primeros frames")


	global.reset_progress()
	Item_level.is_dragging = null
	_delete_save_files(save_mgr)
	save_mgr.load_data()
	await _quit()


func _check_gameplay_scene(global) -> void:
	var ml = current_scene.get_node_or_null("ManagerLevel")
	_check(ml != null, "Falta nodo ManagerLevel")
	_check(current_scene.get_node_or_null("Plato") != null, "Falta nodo Plato")
	_check(current_scene.get_node_or_null("Globo texto/Meal") != null, "Falta nodo Meal")
	_check(current_scene.get_node_or_null("Globo texto/Condition") != null, "Falta nodo Condition")
	if ml == null:
		return

	_check(ml.has_method("get_current_run_index"), "ManagerLevel sin get_current_run_index")
	_check(ml.has_method("get_total_runs"), "ManagerLevel sin get_total_runs")
	if failed:
		return

	_check(str(ml.active_track_key) == "celiaquia", "Track deberia ser celiaquia")
	_check(ml.active_run_data is Dictionary and not ml.active_run_data.is_empty(), "Sin datos de corrida")
	_check(ml.get_current_run_index() == 1, "Deberia ser la primera corrida")
	_check(ml.get_total_runs() >= 1, "Deberia haber al menos una corrida")
	_check(global.get_current_level_number() == 1, "Global deberia estar en capitulo 1")


func _go_to(scene_path: String, label: String) -> void:
	if failed:
		return
	_check(change_scene_to_file(scene_path) == OK, "No se pudo abrir %s" % label)
	if not failed:
		await _wait_for(scene_path, label)


func _call_and_expect(
	method: String, expected_scene: String, label: String, args: Array = []
) -> void:
	if failed:
		return
	_check(current_scene != null, "No hay escena antes de %s" % label)
	_check(
		current_scene != null and current_scene.has_method(method),
		"%s no tiene metodo %s" % [label, method]
	)
	if failed:
		return
	current_scene.callv(method, args)
	await _wait_for(expected_scene, label)


func _wait_for(expected_path: String, label: String) -> void:
	for i in 12:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == expected_path:
			return
	_check(false, "No se llego a %s (%s)" % [label, expected_path])


func _delete_save_files(save_mgr) -> void:
	for path in [save_mgr.SAVE_PATH, save_mgr.TEMP_SAVE_PATH, save_mgr.BACKUP_SAVE_PATH]:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)


func _quit() -> void:
	_stop_audio()
	if is_instance_valid(current_scene):
		var scene = current_scene
		current_scene = null
		scene.free()
	GameChapterAssetCatalog.clear_texture_cache()
	await process_frame
	await process_frame
	quit(1 if failed else 0)


func _stop_audio() -> void:
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	for player in root.find_children("*", "AudioStreamPlayer2D", true, false):
		if player is AudioStreamPlayer2D:
			player.stop()
			player.stream = null


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("SMOKE TEST FAILED: %s" % message)