extends RefCounted


const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const LevelMechanicRegistry := preload("res://niveles/mechanics/LevelMechanicRegistry.gd")
const RUN_RESOURCE_KEYS := [
	"meal_texture_path",
	"condition_texture_path",
	"teaching_texture_path"
]


static func validate(track_chapter_catalog: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	_validate_scene_paths(issues)
	_validate_unknown_tracks(track_chapter_catalog, issues)
	_validate_track_definitions(track_chapter_catalog, issues)
	return issues


static func _validate_scene_paths(issues: Array[String]) -> void:
	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_key := _get_track_key(track_definition)
		_validate_resource_path(
			str(track_definition.get("book_scene_path", "")),
			"%s book scene" % track_key,
			issues
		)
		_validate_resource_path(
			str(track_definition.get("level_scene_path", "")),
			"%s level scene" % track_key,
			issues
		)


static func _validate_unknown_tracks(
	track_chapter_catalog: Dictionary,
	issues: Array[String]
) -> void:
	for raw_track_key in track_chapter_catalog.keys():
		var track_key := str(raw_track_key).strip_edges()
		if not GameTrackCatalog.has_track(track_key):
			issues.append("El catalogo de contenido define un track desconocido: %s" % track_key)


static func _validate_track_definitions(
	track_chapter_catalog: Dictionary,
	issues: Array[String]
) -> void:
	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_key := _get_track_key(track_definition)
		var expected_level_count := max(
			1,
			int(track_definition.get("level_count", GameTrackCatalog.DEFAULT_LEVEL_COUNT))
		)
		_validate_track_chapters(
			track_key,
			expected_level_count,
			track_chapter_catalog.get(track_key, {}),
			issues
		)


static func _validate_track_chapters(
	track_key: String,
	expected_level_count: int,
	raw_chapters: Variant,
	issues: Array[String]
) -> void:
	if not raw_chapters is Dictionary:
		issues.append("El track %s no expone un diccionario de capitulos valido." % track_key)
		return
	var chapters: Dictionary = raw_chapters
	_validate_declared_chapters(track_key, chapters, expected_level_count, issues)
	_validate_expected_chapters(track_key, chapters, expected_level_count, issues)


static func _validate_declared_chapters(
	track_key: String,
	chapters: Dictionary,
	expected_level_count: int,
	issues: Array[String]
) -> void:
	for raw_level_number in chapters.keys():
		var level_number := int(raw_level_number)
		if level_number < 1 or level_number > expected_level_count:
			issues.append(
				"El track %s define un capitulo fuera de rango: %d"
				% [track_key, level_number]
			)


static func _validate_expected_chapters(
	track_key: String,
	chapters: Dictionary,
	expected_level_count: int,
	issues: Array[String]
) -> void:
	for level_number in range(1, expected_level_count + 1):
		if not chapters.has(level_number):
			issues.append("Falta el capitulo %d del track %s." % [level_number, track_key])
			continue
		_validate_chapter_definition(track_key, level_number, chapters[level_number], issues)


static func _validate_chapter_definition(
	track_key: String,
	level_number: int,
	raw_chapter_definition: Variant,
	issues: Array[String]
) -> void:
	if not raw_chapter_definition is Dictionary:
		issues.append(
			"El capitulo %d del track %s no es un diccionario valido."
			% [level_number, track_key]
		)
		return
	var chapter_definition: Dictionary = raw_chapter_definition
	var raw_runs: Variant = chapter_definition.get("runs", [])
	if not raw_runs is Array or raw_runs.is_empty():
		issues.append(
			"El capitulo %d del track %s no define corridas jugables."
			% [level_number, track_key]
		)
		return
	var runs: Array = raw_runs
	for run_index in range(runs.size()):
		_validate_run_definition(track_key, level_number, run_index + 1, runs[run_index], issues)


static func _validate_run_definition(
	track_key: String,
	level_number: int,
	run_index: int,
	raw_run_definition: Variant,
	issues: Array[String]
) -> void:
	if not raw_run_definition is Dictionary:
		issues.append(
			"La corrida %d del capitulo %d en %s no es un diccionario valido."
			% [run_index, level_number, track_key]
		)
		return

	var run_definition: Dictionary = raw_run_definition
	var run_context := _format_run_context(track_key, level_number, run_index)
	var negative_count := int(run_definition.get("negative_count", -1))
	var positive_count := int(run_definition.get("positive_count", -1))
	var category := GameTrackCatalog.normalize_category_code(
		str(run_definition.get("category", ""))
	)

	_validate_run_mechanic(run_definition, run_context, issues)
	_validate_run_teaching_key(track_key, run_definition, run_context, issues)
	_validate_run_counts(negative_count, positive_count, run_context, issues)
	_validate_run_resource_paths(track_key, level_number, run_index, run_definition, issues)
	_validate_run_category(category, run_context, issues)
	_validate_run_payload(
		run_definition,
		negative_count,
		positive_count,
		category,
		run_context,
		issues
	)


static func _validate_run_mechanic(
	run_definition: Dictionary,
	run_context: String,
	issues: Array[String]
) -> void:
	var mechanic_type := LevelMechanicRegistry.normalize_mechanic_type(
		run_definition.get("mechanic_type", ""),
		""
	)
	if not LevelMechanicRegistry.has_mechanic_type(mechanic_type):
		issues.append("%s usa una mecanica desconocida: %s" % [run_context, mechanic_type])


static func _validate_run_teaching_key(
	track_key: String,
	run_definition: Dictionary,
	run_context: String,
	issues: Array[String]
) -> void:
	var teaching_key := str(run_definition.get("teaching_key", "")).strip_edges()
	if teaching_key.is_empty():
		issues.append("%s no define teaching_key." % run_context)
		return
	var track_definition := GameTrackCatalog.get_track_definition(track_key)
	var raw_prefixes: Variant = track_definition.get("teaching_key_prefixes", [])
	var allowed_prefixes: Array = raw_prefixes if raw_prefixes is Array else []
	if allowed_prefixes.is_empty():
		return
	for raw_prefix in allowed_prefixes:
		var prefix := str(raw_prefix).strip_edges()
		if not prefix.is_empty() and teaching_key.begins_with(prefix):
			return
	issues.append(
		"%s deberia usar una teaching_key propia del track: %s"
		% [run_context, teaching_key]
	)


static func _validate_run_counts(
	negative_count: int,
	positive_count: int,
	run_context: String,
	issues: Array[String]
) -> void:
	if negative_count < 0 or positive_count < 0:
		issues.append("%s tiene cantidades negativas." % run_context)
	if negative_count + positive_count <= 0:
		issues.append("%s no tiene items configurados." % run_context)


static func _validate_run_resource_paths(
	track_key: String,
	level_number: int,
	run_index: int,
	run_definition: Dictionary,
	issues: Array[String]
) -> void:
	for raw_resource_key in RUN_RESOURCE_KEYS:
		var resource_key := str(raw_resource_key)
		_validate_resource_path(
			str(run_definition.get(resource_key, "")),
			"%s capitulo %d corrida %d %s"
			% [track_key, level_number, run_index, resource_key],
			issues
		)


static func _validate_run_category(
	category: String,
	run_context: String,
	issues: Array[String]
) -> void:
	if GameTrackCatalog.get_category_label(category, "").is_empty():
		issues.append("%s usa una categoria desconocida: %s" % [run_context, category])


static func _validate_run_payload(
	run_definition: Dictionary,
	negative_count: int,
	positive_count: int,
	category: String,
	run_context: String,
	issues: Array[String]
) -> void:
	var raw_payload: Variant = run_definition.get("mechanic_payload", {})
	if not raw_payload is Dictionary:
		issues.append("%s no define mechanic_payload valido." % run_context)
		return

	var payload: Dictionary = raw_payload
	if int(payload.get("negative_count", -1)) != negative_count:
		issues.append(
			"%s tiene negative_count inconsistente entre run y mechanic_payload."
			% run_context
		)
	if int(payload.get("positive_count", -1)) != positive_count:
		issues.append(
			"%s tiene positive_count inconsistente entre run y mechanic_payload."
			% run_context
		)
	if GameTrackCatalog.normalize_category_code(str(payload.get("category", ""))) != category:
		issues.append(
			"%s tiene categoria inconsistente entre run y mechanic_payload."
			% run_context
		)


static func _get_track_key(track_definition: Dictionary) -> String:
	return str(track_definition.get("key", "")).strip_edges()


static func _format_run_context(track_key: String, level_number: int, run_index: int) -> String:
	return "La corrida %d del capitulo %d en %s" % [run_index, level_number, track_key]


static func _validate_resource_path(
	resource_path: String,
	context: String,
	issues: Array[String]
) -> void:
	var clean_path := resource_path.strip_edges()
	if clean_path.is_empty():
		issues.append("Falta una ruta de recurso para %s." % context)
		return
	if not ResourceLoader.exists(clean_path):
		issues.append("No existe el recurso %s: %s" % [context, clean_path])