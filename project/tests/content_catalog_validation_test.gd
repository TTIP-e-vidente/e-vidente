extends SceneTree

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameLevelContentCatalogScript := preload("res://niveles/helpers/GameLevelContentCatalog.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var catalog = GameLevelContentCatalogScript.new()
	var issues: Array[String] = catalog.get_validation_issues()
	_assert(catalog.is_valid(), "El catalogo de contenido deberia ser valido")
	_assert(issues.is_empty(), _format_issues(issues))
	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_key := str(track_definition.get("key", "")).strip_edges()
		var level_scene_path := str(track_definition.get("level_scene_path", ""))
		var expected_level_count: int = int(GameTrackCatalog.get_track_level_count(track_key))
		_assert(catalog.get_track_level_count(track_key, 0) == expected_level_count, "El track %s deberia exponer la misma cantidad de capitulos que GameTrackCatalog" % track_key)
		_assert(ResourceLoader.exists(str(track_definition.get("book_scene_path", ""))), "El track %s deberia apuntar a una escena de libro existente" % track_key)
		_assert(ResourceLoader.exists(level_scene_path), "El track %s deberia apuntar a una escena de nivel existente" % track_key)
		_validate_track_level_resource(track_key, level_scene_path, expected_level_count, catalog)
		for level_number in range(1, expected_level_count + 1):
			var chapter_definition: Dictionary = catalog.get_chapter_definition(track_key, level_number)
			_assert(not chapter_definition.is_empty(), "El track %s deberia exponer el capitulo %d" % [track_key, level_number])
			_assert(catalog.get_chapter_run_count(track_key, level_number) >= 1, "El capitulo %d del track %s deberia tener al menos una corrida" % [level_number, track_key])
			if track_key == "cetogenica":
				var runs: Array = chapter_definition.get("runs", [])
				for run_definition in runs:
					_assert(str((run_definition as Dictionary).get("teaching_key", "")).begins_with("keto_"), "Cetogenica deberia usar teaching keys propias en el catalogo")
	quit(1 if failed else 0)


func _validate_track_level_resource(track_key: String, level_scene_path: String, expected_level_count: int, catalog) -> void:
	var level_scene: PackedScene = load(level_scene_path) as PackedScene
	_assert(level_scene != null, "El track %s deberia poder cargar su escena jugable" % track_key)
	if level_scene == null:
		return
	var level_instance: Node = level_scene.instantiate()
	_assert(level_instance != null, "El track %s deberia poder instanciar su escena jugable" % track_key)
	if level_instance == null:
		return
	var manager_level = level_instance.get_node_or_null("ManagerLevel")
	_assert(manager_level != null, "La escena %s deberia exponer un ManagerLevel" % level_scene_path)
	if manager_level == null:
		level_instance.free()
		return
	_assert(manager_level.level_resource != null, "La escena %s deberia exponer un LevelResource en ManagerLevel" % level_scene_path)
	_assert(level_instance.has_method("_get_resume_track_key"), "La escena %s deberia exponer el track jugable del nivel" % level_scene_path)
	if level_instance.has_method("_get_resume_track_key"):
		_assert(str(level_instance._get_resume_track_key()) == track_key, "La escena %s deberia estar alineada con el track %s" % [level_scene_path, track_key])
	if manager_level.level_resource != null:
		var level_resource = manager_level.level_resource
		var positive_pool: Array = level_resource.get_positive_items(track_key)
		var negative_pool: Array = level_resource.get_negative_items(track_key)
		for level_number in range(1, expected_level_count + 1):
			for run_index in range(1, catalog.get_chapter_run_count(track_key, level_number) + 1):
				var run_definition: Dictionary = catalog.get_chapter_run(track_key, level_number, run_index)
				var category := str(run_definition.get("category", ""))
				var required_positive_count := int(run_definition.get("positive_count", 0))
				var required_negative_count := int(run_definition.get("negative_count", 0))
				var available_positive_items: Array = catalog.item_categoria(positive_pool, category)
				var available_negative_items: Array = catalog.item_categoria(negative_pool, category)
				_assert(available_positive_items.size() >= required_positive_count, "El track %s capitulo %d corrida %d necesita %d items positivos de categoria %s y la escena solo ofrece %d" % [track_key, level_number, run_index, required_positive_count, category, available_positive_items.size()])
				_assert(available_negative_items.size() >= required_negative_count, "El track %s capitulo %d corrida %d necesita %d items negativos de categoria %s y la escena solo ofrece %d" % [track_key, level_number, run_index, required_negative_count, category, available_negative_items.size()])
	level_instance.free()


func _format_issues(issues: Array[String]) -> String:
	if issues.is_empty():
		return "Sin issues"
	return "El catalogo de contenido tiene problemas:\n- %s" % "\n- ".join(issues)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("CONTENT CATALOG VALIDATION TEST FAILED: %s" % message)
