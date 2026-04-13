extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameTrackChapterDefinitionsScript := preload(
	"res://niveles/content/catalog/GameTrackChapterDefinitions.gd"
)
const GameChapterAssetCatalogScript := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const GameContentCatalogValidatorScript := preload(
	"res://niveles/content/catalog/GameContentCatalogValidator.gd"
)

const BOOK_LEVEL_COMPLETED_KEY := "completed"

var _chapters_by_track: Dictionary = {}


func _init() -> void:
	_chapters_by_track = GameTrackChapterDefinitionsScript.build_track_chapter_catalog()


func filter_items_by_category(items: Array, category_code: String) -> Array:
	if category_code.strip_edges().is_empty():
		return items.duplicate()
	var filtered_items: Array = []
	var wanted_category: String = GameTrackCatalog.normalize_category_code(
		category_code
	)
	for item in items:
		if GameTrackCatalog.categories_match(str(item.categoria), wanted_category):
			filtered_items.append(item)
	return filtered_items


func get_track_level_count(track_key: String, fallback: int = 0) -> int:
	var track_chapters: Dictionary = _chapters_by_track.get(track_key, {})
	return track_chapters.size() if not track_chapters.is_empty() else fallback


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
	var track_chapters: Dictionary = _chapters_by_track.get(track_key, {})
	var chapter_definition: Dictionary = track_chapters.get(level_number, {})
	return chapter_definition.duplicate(true)


func get_chapter_run_count(track_key: String, level_number: int) -> int:
	var chapter_definition: Dictionary = get_chapter_definition(track_key, level_number)
	var runs: Array = chapter_definition.get("runs", [])
	return runs.size()


func get_chapter_run_definition(
	track_key: String,
	level_number: int,
	run_index: int = 1
) -> Dictionary:
	var chapter_definition: Dictionary = get_chapter_definition(track_key, level_number)
	var chapter_runs: Array = chapter_definition.get("runs", [])
	if chapter_runs.is_empty():
		return {}
	var resolved_run_index := clampi(run_index, 1, chapter_runs.size()) - 1
	var run_definition: Dictionary = chapter_runs[resolved_run_index]
	return run_definition.duplicate(true)


func get_validation_issues() -> Array[String]:
	return GameContentCatalogValidatorScript.validate(_chapters_by_track)


func is_valid() -> bool:
	return get_validation_issues().is_empty()


func resolve_texture(texture_ref: Variant) -> Texture2D:
	return GameChapterAssetCatalogScript.resolve_texture(texture_ref)


func build_default_track_progress_state() -> Dictionary:
	var progress_by_track: Dictionary = {}
	for track_key in GameTrackCatalog.get_track_keys():
		progress_by_track[track_key] = build_default_track_progress_for_track(track_key)
	return progress_by_track


func build_default_track_progress_for_track(track_key: String) -> Dictionary:
	var track_progress: Dictionary = {}
	var track_chapters: Dictionary = _chapters_by_track.get(track_key, {})
	for raw_level_number in track_chapters.keys():
		track_progress[int(raw_level_number)] = {
			BOOK_LEVEL_COMPLETED_KEY: false
		}
	return track_progress
