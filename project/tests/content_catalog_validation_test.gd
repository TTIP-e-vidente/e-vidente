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
		var expected_level_count := GameTrackCatalog.get_track_level_count(track_key)
		_assert(catalog.get_track_level_count(track_key, 0) == expected_level_count, "El track %s deberia exponer la misma cantidad de capitulos que GameTrackCatalog" % track_key)
		_assert(ResourceLoader.exists(str(track_definition.get("book_scene_path", ""))), "El track %s deberia apuntar a una escena de libro existente" % track_key)
		_assert(ResourceLoader.exists(str(track_definition.get("level_scene_path", ""))), "El track %s deberia apuntar a una escena de nivel existente" % track_key)
		for level_number in range(1, expected_level_count + 1):
			var chapter_definition: Dictionary = catalog.get_chapter_definition(track_key, level_number)
			_assert(not chapter_definition.is_empty(), "El track %s deberia exponer el capitulo %d" % [track_key, level_number])
			_assert(catalog.get_chapter_run_count(track_key, level_number) >= 1, "El capitulo %d del track %s deberia tener al menos una corrida" % [level_number, track_key])
	quit(1 if failed else 0)


func _format_issues(issues: Array[String]) -> String:
	if issues.is_empty():
		return "Sin issues"
	return "El catalogo de contenido tiene problemas:\n- %s" % "\n- ".join(issues)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("CONTENT CATALOG VALIDATION TEST FAILED: %s" % message)