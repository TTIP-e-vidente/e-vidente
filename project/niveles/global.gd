extends Node

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameLevelContentCatalogScript := preload("res://niveles/helpers/GameLevelContentCatalog.gd")
const GameProgressStateStoreScript := preload("res://niveles/helpers/GameProgressStateStore.gd")

var playerCambiante
var is_dragging: Object
var manager_level
var current_level: int = 1

const LEVEL_STATUS_INDEX := 6
const LEVELS_PER_BOOK := GameTrackCatalog.DEFAULT_LEVEL_COUNT
const TRACK_KEYS := GameTrackCatalog.TRACK_ORDER
const PARTIAL_LEVEL_STATES_KEY := "partial_level_states"
const PARTIAL_LEVEL_RUN_INDEX_KEY := "run_index"
const PARTIAL_LEVEL_MECHANIC_TYPE_KEY := "mechanic_type"
const PARTIAL_LEVEL_MECHANIC_STATE_KEY := "mechanic_state"
const PARTIAL_LEVEL_ITEMS_KEY := "items"
const PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY := "placed_item_ids"
const PARTIAL_LEVEL_ITEM_PATH_KEY := "item_path"
const PARTIAL_LEVEL_INSTANCE_ID_KEY := "instance_id"
const PARTIAL_LEVEL_IS_POSITIVE_KEY := "is_positive"

var _content_catalog
var _progress_store
var items_level: Dictionary = {}
var items_level_vegan: Dictionary = {}
var items_level_vegan_gf: Dictionary = {}
var partial_level_states: Dictionary = {}

func _init() -> void:
	_content_catalog = GameLevelContentCatalogScript.new()
	_progress_store = GameProgressStateStoreScript.new(self)
	items_level = _content_catalog.items_level
	items_level_vegan = _content_catalog.items_level_vegan
	items_level_vegan_gf = _content_catalog.items_level_vegan_gf
	partial_level_states = _progress_store.build_default_partial_level_states()

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
	return _content_catalog.get_track_level_count(track_key, GameTrackCatalog.get_track_level_count(track_key, LEVELS_PER_BOOK))


func get_max_track_level_count() -> int:
	return _content_catalog.get_max_track_level_count(LEVELS_PER_BOOK)

func get_total_level_count() -> int:
	return _content_catalog.get_total_level_count(GameTrackCatalog.get_total_level_count())

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
	var level_counts := {}
	for track_key in get_track_keys():
		level_counts[track_key] = get_track_level_count(track_key)
	return level_counts


func get_chapter_definition(track_key: String, level_number: int) -> Dictionary:
	return _content_catalog.get_chapter_definition(track_key, level_number)


func get_chapter_run_count(track_key: String, level_number: int) -> int:
	return _content_catalog.get_chapter_run_count(track_key, level_number)


func get_chapter_run_definition(track_key: String, level_number: int, run_index: int = 1) -> Dictionary:
	return _content_catalog.get_chapter_run(track_key, level_number, run_index)

func get_book_progress(track_key: String) -> Dictionary:
	return _book_for_track(track_key)

func mark_level_completed(track_key: String, level_number: int) -> void:
	var book := _book_for_track(track_key)
	var clean_level_number := clampi(level_number, 1, get_track_level_count(track_key))
	if book.has(clean_level_number):
		book[clean_level_number][LEVEL_STATUS_INDEX] = true

func is_level_unlocked(track_key: String, level_number: int) -> bool:
	var clean_level_number := clampi(level_number, 1, get_track_level_count(track_key))
	if clean_level_number <= 1:
		return true
	return _is_level_completed(track_key, clean_level_number - 1)

func format_progress_summary_text(summary: Dictionary = {}) -> String:
	var resolved_summary := summary if not summary.is_empty() else get_progress_summary()
	var lines: Array[String] = []
	lines.append("%d de %d capitulos completos" % [int(resolved_summary.get("total", 0)), int(resolved_summary.get("max_total", get_total_level_count()))])
	for track_definition in get_track_definitions():
		var track_key := str(track_definition.get("key", "")).strip_edges()
		if track_key.is_empty():
			continue
		lines.append("%s %d/%d" % [str(track_definition.get("summary_label", track_definition.get("label", "Tu progreso"))), int(resolved_summary.get(track_key, 0)), get_track_level_count(track_key)])
	return "\n".join(lines)

func item_categoria(items, cate):
	return _content_catalog.item_categoria(items, cate)

func resolve_texture(texture_ref: Variant) -> Texture2D:
	return _content_catalog.resolve_texture(texture_ref)

func reset_progress() -> void:
	_progress_store.reset_progress()

func export_progress() -> Dictionary:
	return _progress_store.export_progress()

func import_progress(progress: Dictionary) -> void:
	_progress_store.import_progress(progress)

func get_progress_summary() -> Dictionary:
	return _progress_store.get_progress_summary()

func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	return _progress_store.get_partial_level_state(track_key, level_number)

func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	_progress_store.set_partial_level_state(track_key, level_number, state)

func clear_partial_level_state(track_key: String, level_number: int) -> void:
	_progress_store.clear_partial_level_state(track_key, level_number)

func _get_track_books() -> Dictionary:
	return _content_catalog.get_track_books()

func _book_for_track(track_key: String) -> Dictionary:
	return _content_catalog.book_for_track(track_key)

func _is_level_completed(track_key: String, level_number: int) -> bool:
	var book := _book_for_track(track_key)
	if not book.has(level_number):
		return false
	return bool(book[level_number][LEVEL_STATUS_INDEX])
