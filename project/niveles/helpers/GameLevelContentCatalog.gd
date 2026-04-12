extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameTrackChapterDefinitionsScript := preload(
	"res://niveles/helpers/catalog/GameTrackChapterDefinitions.gd"
)
const GameChapterAssetCatalogScript := preload(
	"res://niveles/helpers/catalog/GameChapterAssetCatalog.gd"
)
const GameContentCatalogValidatorScript := preload(
	"res://niveles/helpers/catalog/GameContentCatalogValidator.gd"
)

const BOOK_LEVEL_NEGATIVE_COUNT_KEY := "negative_count"
const BOOK_LEVEL_POSITIVE_COUNT_KEY := "positive_count"
const BOOK_LEVEL_MEAL_TEXTURE_PATH_KEY := "meal_texture_path"
const BOOK_LEVEL_CONDITION_TEXTURE_PATH_KEY := "condition_texture_path"
const BOOK_LEVEL_TEACHING_TEXTURE_PATH_KEY := "teaching_texture_path"
const BOOK_LEVEL_CATEGORY_KEY := "category"
const BOOK_LEVEL_COMPLETED_KEY := "completed"

var _track_chapter_catalog: Dictionary = {}
var _default_track_progress_templates: Dictionary = {}


func _init() -> void:
	_track_chapter_catalog = _build_track_chapter_catalog()
	_default_track_progress_templates = _build_default_track_progress_templates()


func filter_items_by_category(items: Array, category_code: String) -> Array:
	if category_code.strip_edges().is_empty():
		return items.duplicate()
	var filtered_items: Array = []
	var normalized_category_code: String = GameTrackCatalog.normalize_category_code(
		category_code
	)
	for item in items:
		if GameTrackCatalog.categories_match(str(item.categoria), normalized_category_code):
			filtered_items.append(item)
	return filtered_items


func get_track_level_count(track_key: String, fallback: int = 0) -> int:
	var track_chapter_catalog: Dictionary = _chapter_catalog_for_track(track_key)
	return track_chapter_catalog.size() if not track_chapter_catalog.is_empty() else fallback


func get_max_track_level_count(fallback: int = 0) -> int:
	var max_level_count := fallback
	for track_key in GameTrackCatalog.get_track_keys():
		max_level_count = max(max_level_count, get_track_level_count(track_key, fallback))
	return max_level_count


func get_total_level_count(fallback: int = 0) -> int:
	var total_levels := 0
	for track_key in GameTrackCatalog.get_track_keys():
		total_levels += get_track_level_count(track_key, fallback)
	return total_levels


func get_chapter_definition(track_key: String, level_number: int) -> Dictionary:
	var track_chapter_catalog: Dictionary = _chapter_catalog_for_track(track_key)
	if not track_chapter_catalog.has(level_number):
		return {}
	var chapter_definition: Variant = track_chapter_catalog.get(level_number, {})
	return chapter_definition.duplicate(true) if chapter_definition is Dictionary else {}


func get_chapter_run_count(track_key: String, level_number: int) -> int:
	return _chapter_runs_for_level(track_key, level_number).size()


func get_chapter_run_definition(
	track_key: String,
	level_number: int,
	run_index: int = 1
) -> Dictionary:
	var chapter_runs: Array = _chapter_runs_for_level(track_key, level_number)
	if chapter_runs.is_empty():
		return {}
	var resolved_run_index := clampi(run_index, 1, chapter_runs.size()) - 1
	var run_definition: Variant = chapter_runs[resolved_run_index]
	return run_definition.duplicate(true) if run_definition is Dictionary else {}


func get_track_chapter_catalog() -> Dictionary:
	return _track_chapter_catalog.duplicate(true)


func get_validation_issues() -> Array[String]:
	return GameContentCatalogValidatorScript.validate(_track_chapter_catalog)


func is_valid() -> bool:
	return get_validation_issues().is_empty()


func resolve_texture(texture_ref: Variant) -> Texture2D:
	return GameChapterAssetCatalogScript.resolve_texture(texture_ref)


func build_default_track_progress_state() -> Dictionary:
	return get_default_track_progress_templates()


func build_default_track_progress_for_track(track_key: String) -> Dictionary:
	return get_default_track_progress_template(track_key)


func get_default_track_progress_templates() -> Dictionary:
	return _default_track_progress_templates.duplicate(true)


func get_default_track_progress_template(track_key: String) -> Dictionary:
	var progress_template: Variant = _default_track_progress_templates.get(track_key, {})
	return progress_template.duplicate(true) if progress_template is Dictionary else {}


func _build_track_chapter_catalog() -> Dictionary:
	return GameTrackChapterDefinitionsScript.build_track_chapter_catalog()


func _build_default_track_progress_templates() -> Dictionary:
	var default_track_progress_templates: Dictionary = {}
	for track_key in GameTrackCatalog.get_track_keys():
		default_track_progress_templates[track_key] = _build_default_track_progress_template(
			track_key
		)
	return default_track_progress_templates


func _build_default_track_progress_template(track_key: String) -> Dictionary:
	var default_track_progress_template: Dictionary = {}
	var track_chapter_catalog: Dictionary = _chapter_catalog_for_track(track_key)
	if track_chapter_catalog.is_empty():
		return default_track_progress_template
	for level_number in _sorted_level_numbers(track_chapter_catalog):
		default_track_progress_template[level_number] = _build_level_progress_template(
			track_key,
			level_number
		)
	return default_track_progress_template


func _build_level_progress_template(track_key: String, level_number: int) -> Dictionary:
	var first_run: Dictionary = get_chapter_run_definition(track_key, level_number, 1)
	return {
		BOOK_LEVEL_NEGATIVE_COUNT_KEY: int(first_run.get(BOOK_LEVEL_NEGATIVE_COUNT_KEY, 0)),
		BOOK_LEVEL_POSITIVE_COUNT_KEY: int(first_run.get(BOOK_LEVEL_POSITIVE_COUNT_KEY, 0)),
		BOOK_LEVEL_MEAL_TEXTURE_PATH_KEY: str(
			first_run.get(BOOK_LEVEL_MEAL_TEXTURE_PATH_KEY, "")
		),
		BOOK_LEVEL_CONDITION_TEXTURE_PATH_KEY: str(
			first_run.get(BOOK_LEVEL_CONDITION_TEXTURE_PATH_KEY, "")
		),
		BOOK_LEVEL_TEACHING_TEXTURE_PATH_KEY: str(
			first_run.get(BOOK_LEVEL_TEACHING_TEXTURE_PATH_KEY, "")
		),
		BOOK_LEVEL_CATEGORY_KEY: str(first_run.get(BOOK_LEVEL_CATEGORY_KEY, "")),
		BOOK_LEVEL_COMPLETED_KEY: false
	}


func _chapter_catalog_for_track(track_key: String) -> Dictionary:
	var raw_track_chapter_catalog: Variant = _track_chapter_catalog.get(track_key, {})
	return raw_track_chapter_catalog if raw_track_chapter_catalog is Dictionary else {}


func _chapter_runs_for_level(track_key: String, level_number: int) -> Array:
	var raw_chapter_runs: Variant = get_chapter_definition(track_key, level_number).get(
		"runs",
		[]
	)
	return raw_chapter_runs if raw_chapter_runs is Array else []


func _sorted_level_numbers(chapter_definitions: Dictionary) -> Array[int]:
	var level_numbers: Array[int] = []
	for raw_level_number in chapter_definitions.keys():
		level_numbers.append(int(raw_level_number))
	level_numbers.sort()
	return level_numbers
