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
	for raw_track_key in track_chapter_catalog.keys():
		var track_key: String = str(raw_track_key).strip_edges()
		if GameTrackCatalog.has_track(track_key):
			continue
		issues.append("El catalogo de contenido define un track desconocido: %s" % track_key)

	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_key: String = str(track_definition.get("key", "")).strip_edges()
		var expected_level_count: int = max(
			1,
			int(track_definition.get("level_count", GameTrackCatalog.DEFAULT_LEVEL_COUNT))
		)
		var book_scene_path: String = str(track_definition.get("book_scene_path", ""))
		var level_scene_path: String = str(track_definition.get("level_scene_path", ""))
		var raw_prefixes: Variant = track_definition.get("teaching_key_prefixes", [])
		var teaching_key_prefixes: Array = (
			raw_prefixes if raw_prefixes is Array else []
		)

		_validate_resource_path(
			book_scene_path,
			"%s book scene" % track_key,
			issues
		)
		_validate_resource_path(
			level_scene_path,
			"%s level scene" % track_key,
			issues
		)

		var raw_track_chapters: Variant = track_chapter_catalog.get(track_key, {})
		if not raw_track_chapters is Dictionary:
			issues.append(
				"El track %s no expone un diccionario de capitulos valido." % track_key
			)
			continue

		var track_chapters: Dictionary = raw_track_chapters
		for raw_level_number in track_chapters.keys():
			var level_number: int = int(raw_level_number)
			if level_number >= 1 and level_number <= expected_level_count:
				continue
			issues.append(
				"El track %s define un capitulo fuera de rango: %d"
				% [track_key, level_number]
			)

		for level_number in range(1, expected_level_count + 1):
			if not track_chapters.has(level_number):
				issues.append(
					"Falta el capitulo %d del track %s." % [level_number, track_key]
				)
				continue

			var raw_chapter_definition: Variant = track_chapters[level_number]
			if not raw_chapter_definition is Dictionary:
				issues.append(
					"El capitulo %d del track %s no es un diccionario valido."
					% [level_number, track_key]
				)
				continue

			var chapter_definition: Dictionary = raw_chapter_definition
			var raw_runs: Variant = chapter_definition.get("runs", [])
			if not raw_runs is Array or raw_runs.is_empty():
				issues.append(
					"El capitulo %d del track %s no define corridas jugables."
					% [level_number, track_key]
				)
				continue

			var runs: Array = raw_runs
			for run_index in range(runs.size()):
				var run_number: int = run_index + 1
				var run_context: String = (
					"La corrida %d del capitulo %d en %s"
					% [run_number, level_number, track_key]
				)
				var raw_run_definition: Variant = runs[run_index]
				if not raw_run_definition is Dictionary:
					issues.append(
						"La corrida %d del capitulo %d en %s no es un diccionario valido."
						% [run_number, level_number, track_key]
					)
					continue

				var run_definition: Dictionary = raw_run_definition
				var mechanic_type: String = LevelMechanicRegistry.normalize_mechanic_type(
					run_definition.get("mechanic_type", ""),
					""
				)
				var teaching_key: String = str(
					run_definition.get("teaching_key", "")
				).strip_edges()
				var negative_count: int = int(run_definition.get("negative_count", -1))
				var positive_count: int = int(run_definition.get("positive_count", -1))
				var category: String = GameTrackCatalog.normalize_category_code(
					str(run_definition.get("category", ""))
				)

				if not LevelMechanicRegistry.has_mechanic_type(mechanic_type):
					issues.append(
						"%s usa una mecanica desconocida: %s"
						% [run_context, mechanic_type]
					)

				if teaching_key.is_empty():
					issues.append("%s no define teaching_key." % run_context)
				elif not teaching_key_prefixes.is_empty():
					var matches_track: bool = false
					for raw_prefix in teaching_key_prefixes:
						var prefix: String = str(raw_prefix).strip_edges()
						if prefix.is_empty() or not teaching_key.begins_with(prefix):
							continue
						matches_track = true
						break
					if not matches_track:
						issues.append(
							"%s deberia usar una teaching_key propia del track: %s"
							% [run_context, teaching_key]
						)

				if negative_count < 0 or positive_count < 0:
					issues.append("%s tiene cantidades negativas." % run_context)
				if negative_count + positive_count <= 0:
					issues.append("%s no tiene items configurados." % run_context)

				for raw_resource_key in RUN_RESOURCE_KEYS:
					var resource_key: String = str(raw_resource_key)
					_validate_resource_path(
						str(run_definition.get(resource_key, "")),
						"%s capitulo %d corrida %d %s"
						% [track_key, level_number, run_number, resource_key],
						issues
					)

				if GameTrackCatalog.get_category_label(category, "").is_empty():
					issues.append(
						"%s usa una categoria desconocida: %s"
						% [run_context, category]
					)

				var payload: Variant = run_definition.get("mechanic_payload", {})
				if not payload is Dictionary:
					issues.append("%s no define mechanic_payload valido." % run_context)
					continue

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
				if (
					GameTrackCatalog.normalize_category_code(
						str(payload.get("category", ""))
					)
					!= category
				):
					issues.append(
						"%s tiene categoria inconsistente entre run y mechanic_payload."
						% run_context
					)
	return issues


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