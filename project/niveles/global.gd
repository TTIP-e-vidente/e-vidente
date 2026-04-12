extends Node

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameLevelContentCatalogScript := preload(
	"res://niveles/helpers/GameLevelContentCatalog.gd"
)
const GameProgressStateStoreScript := preload(
	"res://niveles/helpers/GameProgressStateStore.gd"
)

var player_cambiante
var is_dragging: Object
var manager_level
var current_level: int = 1

const LEVELS_PER_BOOK := GameTrackCatalog.DEFAULT_LEVEL_COUNT
const TRACK_KEYS := GameTrackCatalog.TRACK_ORDER
const BOOK_LEVEL_COMPLETED_KEY := GameLevelContentCatalogScript.BOOK_LEVEL_COMPLETED_KEY
const PARTIAL_LEVEL_STATES_KEY := "partial_level_states"
const PROGRESS_SYSTEM_STATES_KEY := "progress_system_states"
const PARTIAL_LEVEL_RUN_INDEX_KEY := "run_index"
const PARTIAL_LEVEL_MECHANIC_TYPE_KEY := "mechanic_type"
const PARTIAL_LEVEL_MECHANIC_STATE_KEY := "mechanic_state"
const PARTIAL_LEVEL_ITEMS_KEY := "items"
const PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY := "placed_item_ids"
const PARTIAL_LEVEL_ITEM_PATH_KEY := "item_path"
const PARTIAL_LEVEL_INSTANCE_ID_KEY := "instance_id"
const PARTIAL_LEVEL_IS_POSITIVE_KEY := "is_positive"

var _content_catalog
var _campaign_progress_store
var campaign_progress_by_track: Dictionary = {}
var partial_level_state_by_track: Dictionary = {}
var progress_system_state_by_key: Dictionary = {}


func _init() -> void:
	_content_catalog = GameLevelContentCatalogScript.new()
	_campaign_progress_store = GameProgressStateStoreScript.new(self)
	campaign_progress_by_track = build_default_campaign_progress_state()
	partial_level_state_by_track = _campaign_progress_store.build_empty_partial_level_state_map()
	progress_system_state_by_key = _campaign_progress_store.build_empty_progress_system_state_map()


func get_track_definitions() -> Array:
	return GameTrackCatalog.get_track_definitions()


func get_track_keys() -> Array:
	return GameTrackCatalog.get_track_keys()


func has_track(track_key: String) -> bool:
	return GameTrackCatalog.has_track(track_key)


func get_track_label(track_key: String) -> String:
	return GameTrackCatalog.get_track_label(track_key, "Tu progreso")


func get_track_summary_label(track_key: String) -> String:
	return GameTrackCatalog.get_track_summary_label(track_key, "Tu progreso")


func get_track_level_count(track_key: String = "") -> int:
	var fallback_level_count := GameTrackCatalog.get_track_level_count(
		track_key,
		LEVELS_PER_BOOK
	)
	return _content_catalog.get_track_level_count(track_key, fallback_level_count)


func get_max_track_level_count() -> int:
	return _content_catalog.get_max_track_level_count(LEVELS_PER_BOOK)


func get_total_level_count() -> int:
	return _content_catalog.get_total_level_count(
		GameTrackCatalog.get_total_level_count()
	)


func get_book_scene_path(track_key: String) -> String:
	return GameTrackCatalog.get_book_scene_path(track_key, "res://interface/archivero.tscn")


func get_level_scene_path(track_key: String) -> String:
	return GameTrackCatalog.get_level_scene_path(track_key, "res://interface/archivero.tscn")


func get_track_book_scene_paths() -> Dictionary:
	return GameTrackCatalog.get_book_scene_paths()


func get_track_level_scene_paths() -> Dictionary:
	return GameTrackCatalog.get_level_scene_paths()


func get_track_labels() -> Dictionary:
	return GameTrackCatalog.get_track_labels()


func get_track_level_counts() -> Dictionary:
	var level_counts: Dictionary = {}
	for track_key in get_track_keys():
		level_counts[track_key] = get_track_level_count(track_key)
	return level_counts


func get_chapter_definition(track_key: String, level_number: int) -> Dictionary:
	return _content_catalog.get_chapter_definition(track_key, level_number)


func get_chapter_run_count(track_key: String, level_number: int) -> int:
	return _content_catalog.get_chapter_run_count(track_key, level_number)


func get_chapter_run_definition(
	track_key: String,
	level_number: int,
	run_index: int = 1
) -> Dictionary:
	return _content_catalog.get_chapter_run_definition(
		track_key,
		level_number,
		run_index
	)


func filter_items_by_category(items: Array, category: String) -> Array:
	return _content_catalog.filter_items_by_category(items, category)


func resolve_texture(texture_ref: Variant) -> Texture2D:
	return _content_catalog.resolve_texture(texture_ref)


func get_current_level_number() -> int:
	return current_level


func set_current_level_number(level_number: int, track_key: String = "") -> void:
	current_level = _resolve_track_level_number(track_key, level_number)


func build_default_campaign_progress_state() -> Dictionary:
	return _content_catalog.build_default_track_progress_state()


func get_campaign_progress_for_track(track_key: String) -> Dictionary:
	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty():
		return {}
	if not campaign_progress_by_track.has(clean_track_key):
		campaign_progress_by_track[clean_track_key] = (
			_content_catalog.build_default_track_progress_for_track(clean_track_key)
		)
	var stored_track_progress: Variant = campaign_progress_by_track.get(clean_track_key, {})
	return stored_track_progress if stored_track_progress is Dictionary else {}


func mark_level_completed(track_key: String, level_number: int) -> void:
	_write_track_level_completion(track_key, level_number, true)


func is_level_unlocked(track_key: String, level_number: int) -> bool:
	var resolved_level_number := _resolve_track_level_number(track_key, level_number)
	if resolved_level_number <= 1:
		return true
	return is_level_completed(track_key, resolved_level_number - 1)


func is_level_completed(track_key: String, level_number: int) -> bool:
	var level_progress: Dictionary = _read_track_level_progress(track_key, level_number)
	if level_progress.is_empty():
		return false
	return bool(level_progress.get(BOOK_LEVEL_COMPLETED_KEY, false))


func format_progress_summary_text(summary: Dictionary = {}) -> String:
	var progress_summary := _resolve_progress_summary_data(summary)
	var lines: Array[String] = []
	for track_definition in get_track_definitions():
		var progress_line := _format_track_progress_line(
			track_definition,
			progress_summary
		)
		if progress_line.is_empty():
			continue
		lines.append(progress_line)
	return "\n".join(lines)


func reset_progress() -> void:
	_campaign_progress_store.reset_progress()


func export_progress() -> Dictionary:
	return _campaign_progress_store.export_progress()


func import_progress(progress: Dictionary) -> void:
	_campaign_progress_store.import_progress(progress)


func get_progress_summary() -> Dictionary:
	return _campaign_progress_store.get_progress_summary()


func get_progress_system_state(system_key: String) -> Dictionary:
	return _campaign_progress_store.get_progress_system_state(system_key)


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	_campaign_progress_store.set_progress_system_state(system_key, system_state)


func clear_progress_system_state(system_key: String) -> void:
	_campaign_progress_store.clear_progress_system_state(system_key)


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	return _campaign_progress_store.get_partial_level_state(track_key, level_number)


func set_partial_level_state(
	track_key: String,
	level_number: int,
	state: Dictionary
) -> void:
	_campaign_progress_store.set_partial_level_state(track_key, level_number, state)


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	_campaign_progress_store.clear_partial_level_state(track_key, level_number)


func _resolve_progress_summary_data(summary: Dictionary) -> Dictionary:
	return summary if not summary.is_empty() else get_progress_summary()


func _format_track_progress_line(
	track_definition: Dictionary,
	progress_summary: Dictionary
) -> String:
	var track_key := str(track_definition.get("key", "")).strip_edges()
	if track_key.is_empty():
		return ""
	var level_count: int = get_track_level_count(track_key)
	var completed_level_count: int = int(progress_summary.get(track_key, 0))
	var display_progress: int = _resolve_track_progress_display_value(
		level_count,
		completed_level_count
	)
	return "%s %d/%d" % [
		_resolve_track_summary_label(track_definition),
		display_progress,
		level_count
	]


func _resolve_track_summary_label(track_definition: Dictionary) -> String:
	return str(
		track_definition.get(
			"summary_label",
			track_definition.get("label", "Tu progreso")
		)
	)


func _write_track_level_completion(
	track_key: String,
	level_number: int,
	completed: bool
) -> void:
	var resolved_level_number := _resolve_track_level_number(track_key, level_number)
	var track_progress := get_campaign_progress_for_track(track_key)
	if not track_progress.has(resolved_level_number):
		return
	var raw_level_progress: Variant = track_progress.get(resolved_level_number, {})
	if not raw_level_progress is Dictionary:
		return
	var level_progress: Dictionary = raw_level_progress
	level_progress[BOOK_LEVEL_COMPLETED_KEY] = completed
	track_progress[resolved_level_number] = level_progress


func _read_track_level_progress(track_key: String, level_number: int) -> Dictionary:
	var track_progress := get_campaign_progress_for_track(track_key)
	var resolved_level_number := _resolve_track_level_number(track_key, level_number)
	var raw_level_progress: Variant = track_progress.get(resolved_level_number, {})
	return raw_level_progress if raw_level_progress is Dictionary else {}


func _resolve_track_level_number(track_key: String, level_number: int) -> int:
	var clean_track_key := track_key.strip_edges()
	var max_level_count := get_max_track_level_count()
	if has_track(clean_track_key):
		max_level_count = get_track_level_count(clean_track_key)
	if max_level_count <= 0:
		return 1
	return clampi(level_number, 1, max_level_count)


func _resolve_track_progress_display_value(
	level_count: int,
	completed_level_count: int
) -> int:
	if level_count <= 0:
		return 0
	if completed_level_count >= level_count:
		return level_count
	return clampi(completed_level_count + 1, 1, level_count)
