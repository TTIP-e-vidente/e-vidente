extends RefCounted


const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const LevelMechanicRegistry := preload("res://niveles/mechanics/LevelMechanicRegistry.gd")


static func validate(track_chapter_definitions: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	_validate_scene_paths(issues)
	_validate_unknown_tracks(track_chapter_definitions, issues)
	_validate_track_definitions(track_chapter_definitions, issues)
	return issues


static func _validate_scene_paths(issues: Array[String]) -> void:
	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_key := str(track_definition.get("key", "")).strip_edges()
		_validate_resource_path(str(track_definition.get("book_scene_path", "")), "%s book scene" % track_key, issues)
		_validate_resource_path(str(track_definition.get("level_scene_path", "")), "%s level scene" % track_key, issues)


static func _validate_unknown_tracks(track_chapter_definitions: Dictionary, issues: Array[String]) -> void:
	for raw_track_key in track_chapter_definitions.keys():
		var track_key := str(raw_track_key).strip_edges()
		if not GameTrackCatalog.has_track(track_key):
			issues.append("El catalogo de contenido define un track desconocido: %s" % track_key)


static func _validate_track_definitions(track_chapter_definitions: Dictionary, issues: Array[String]) -> void:
	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_key := str(track_definition.get("key", "")).strip_edges()
		var expected_level_count := GameTrackCatalog.get_track_level_count(track_key)
		var raw_chapters: Variant = track_chapter_definitions.get(track_key, {})
		if not raw_chapters is Dictionary:
			issues.append("El track %s no expone un diccionario de capitulos valido." % track_key)
			continue
		var chapters: Dictionary = raw_chapters
		for raw_level_number in chapters.keys():
			var level_number := int(raw_level_number)
			if level_number < 1 or level_number > expected_level_count:
				issues.append("El track %s define un capitulo fuera de rango: %d" % [track_key, level_number])
		for level_number in range(1, expected_level_count + 1):
			if not chapters.has(level_number):
				issues.append("Falta el capitulo %d del track %s." % [level_number, track_key])
				continue
			_validate_chapter_definition(track_key, level_number, chapters[level_number], issues)


static func _validate_chapter_definition(track_key: String, level_number: int, raw_chapter_definition: Variant, issues: Array[String]) -> void:
	if not raw_chapter_definition is Dictionary:
		issues.append("El capitulo %d del track %s no es un diccionario valido." % [level_number, track_key])
		return
	var chapter_definition: Dictionary = raw_chapter_definition
	var raw_runs: Variant = chapter_definition.get("runs", [])
	if not raw_runs is Array or raw_runs.is_empty():
		issues.append("El capitulo %d del track %s no define corridas jugables." % [level_number, track_key])
		return
	var runs: Array = raw_runs
	for run_index in range(runs.size()):
		_validate_run_definition(track_key, level_number, run_index + 1, runs[run_index], issues)


static func _validate_run_definition(track_key: String, level_number: int, run_index: int, raw_run_definition: Variant, issues: Array[String]) -> void:
	if not raw_run_definition is Dictionary:
		issues.append("La corrida %d del capitulo %d en %s no es un diccionario valido." % [run_index, level_number, track_key])
		return
	var run_definition: Dictionary = raw_run_definition
	var teaching_key := str(run_definition.get("teaching_key", "")).strip_edges()
	var mechanic_type := LevelMechanicRegistry.normalize_mechanic_type(run_definition.get("mechanic_type", ""), "")
	if not LevelMechanicRegistry.has_mechanic_type(mechanic_type):
		issues.append("La corrida %d del capitulo %d en %s usa una mecanica desconocida: %s" % [run_index, level_number, track_key, mechanic_type])
	if teaching_key.is_empty():
		issues.append("La corrida %d del capitulo %d en %s no define teaching_key." % [run_index, level_number, track_key])
	elif track_key == "cetogenica" and not teaching_key.begins_with("keto_"):
		issues.append("La corrida %d del capitulo %d en %s deberia usar una teaching_key propia del track: %s" % [run_index, level_number, track_key, teaching_key])
	var negative_count := int(run_definition.get("negative_count", -1))
	var positive_count := int(run_definition.get("positive_count", -1))
	if negative_count < 0 or positive_count < 0:
		issues.append("La corrida %d del capitulo %d en %s tiene cantidades negativas." % [run_index, level_number, track_key])
	if negative_count + positive_count <= 0:
		issues.append("La corrida %d del capitulo %d en %s no tiene items configurados." % [run_index, level_number, track_key])
	_validate_resource_path(str(run_definition.get("meal_texture_path", "")), "%s capitulo %d corrida %d meal_texture_path" % [track_key, level_number, run_index], issues)
	_validate_resource_path(str(run_definition.get("condition_texture_path", "")), "%s capitulo %d corrida %d condition_texture_path" % [track_key, level_number, run_index], issues)
	_validate_resource_path(str(run_definition.get("teaching_texture_path", "")), "%s capitulo %d corrida %d teaching_texture_path" % [track_key, level_number, run_index], issues)
	var category := GameTrackCatalog.normalize_category_code(str(run_definition.get("category", "")))
	if GameTrackCatalog.get_category_label(category, "").is_empty():
		issues.append("La corrida %d del capitulo %d en %s usa una categoria desconocida: %s" % [run_index, level_number, track_key, category])
	var raw_payload: Variant = run_definition.get("mechanic_payload", {})
	if not raw_payload is Dictionary:
		issues.append("La corrida %d del capitulo %d en %s no define mechanic_payload valido." % [run_index, level_number, track_key])
		return
	var payload: Dictionary = raw_payload
	if int(payload.get("negative_count", -1)) != negative_count:
		issues.append("La corrida %d del capitulo %d en %s tiene negative_count inconsistente entre run y mechanic_payload." % [run_index, level_number, track_key])
	if int(payload.get("positive_count", -1)) != positive_count:
		issues.append("La corrida %d del capitulo %d en %s tiene positive_count inconsistente entre run y mechanic_payload." % [run_index, level_number, track_key])
	if GameTrackCatalog.normalize_category_code(str(payload.get("category", ""))) != category:
		issues.append("La corrida %d del capitulo %d en %s tiene categoria inconsistente entre run y mechanic_payload." % [run_index, level_number, track_key])


static func _validate_resource_path(resource_path: String, context: String, issues: Array[String]) -> void:
	var clean_path := resource_path.strip_edges()
	if clean_path.is_empty():
		issues.append("Falta una ruta de recurso para %s." % context)
		return
	if not ResourceLoader.exists(clean_path):
		issues.append("No existe el recurso %s: %s" % [context, clean_path])