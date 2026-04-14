extends Node
## Fachada publica del estado global de niveles.
##
## Expone un punto unico para consultar contenido, progreso y estado parcial,
## pero deja la logica pesada repartida en el catalogo de contenido y el store
## de progreso.

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameLevelContentCatalogScript := preload(
	"res://niveles/content/GameLevelContentCatalog.gd"
)
const GameProgressStateStoreScript := preload(
	"res://niveles/progress/GameProgressStateStore.gd"
)

var player_cambiante
var is_dragging: Object
var manager_level
var current_level: int = 1

const LEVELS_PER_BOOK := GameTrackCatalog.DEFAULT_LEVEL_COUNT
const TRACK_KEYS := GameTrackCatalog.TRACK_ORDER
const BOOK_LEVEL_COMPLETED_KEY := GameLevelContentCatalogScript.BOOK_LEVEL_COMPLETED_KEY
const DEFAULT_PROGRESS_LABEL := "Tu progreso"
const PROGRESS_SYSTEM_STATES_KEY := "progress_system_states"
const PARTIAL_LEVEL_STATES_KEY := "partial_level_states"
const PARTIAL_LEVEL_RUN_INDEX_KEY := "run_index"
const PARTIAL_LEVEL_MECHANIC_TYPE_KEY := "mechanic_type"
const PARTIAL_LEVEL_MECHANIC_STATE_KEY := "mechanic_state"
const PARTIAL_LEVEL_ITEMS_KEY := "items"
const PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY := "placed_item_ids"
const PARTIAL_LEVEL_ITEM_PATH_KEY := "item_path"
const PARTIAL_LEVEL_INSTANCE_ID_KEY := "instance_id"
const PARTIAL_LEVEL_IS_POSITIVE_KEY := "is_positive"

var _level_content_catalog
var _progress_state_store
var campaign_progress_by_track: Dictionary = {}
var partial_level_state_by_track: Dictionary = {}
var progress_system_state_by_key: Dictionary = {}


func _init() -> void:
	_level_content_catalog = GameLevelContentCatalogScript.new()
	_progress_state_store = GameProgressStateStoreScript.new(self)
	_reset_runtime_progress_state()


func get_track_level_count(track_key: String = "") -> int:
	return _level_content_catalog.get_track_level_count(
		track_key,
		GameTrackCatalog.get_track_level_count(track_key, LEVELS_PER_BOOK)
	)


func get_max_track_level_count() -> int:
	return _level_content_catalog.get_max_track_level_count(LEVELS_PER_BOOK)


func get_total_level_count() -> int:
	return _level_content_catalog.get_total_level_count(
		GameTrackCatalog.get_total_level_count()
	)


func get_chapter_definition(track_key: String, level_number: int) -> Dictionary:
	return _level_content_catalog.get_chapter_definition(track_key, level_number)


func get_chapter_run_count(track_key: String, level_number: int) -> int:
	return _level_content_catalog.get_chapter_run_count(track_key, level_number)


func get_chapter_run_definition(
	track_key: String,
	level_number: int,
	run_index: int = 1
) -> Dictionary:
	return _level_content_catalog.get_chapter_run_definition(
		track_key,
		level_number,
		run_index
	)


func filter_items_by_category(items: Array, category: String) -> Array:
	return _level_content_catalog.filter_items_by_category(items, category)


func resolve_texture(texture_ref: Variant) -> Texture2D:
	return _level_content_catalog.resolve_texture(texture_ref)


func build_default_campaign_progress_state() -> Dictionary:
	return _level_content_catalog.build_default_track_progress_state()


# Nivel actual.
func get_current_level_number() -> int:
	return current_level


func set_current_level_number(level_number: int, track_key: String = "") -> void:
	current_level = _clamp_level_number_for_track(track_key, level_number)


# Progreso de campaña visible por track y capitulo.
func get_campaign_progress_for_track(track_key: String) -> Dictionary:
	var resolved_track_key: String = _resolve_existing_track_key(track_key)
	if resolved_track_key.is_empty():
		return {}

	_ensure_track_progress_exists(resolved_track_key)
	return _read_track_progress_dictionary(resolved_track_key)


func mark_level_completed(track_key: String, level_number: int) -> void:
	var track_progress := get_campaign_progress_for_track(track_key)
	if track_progress.is_empty():
		return

	var resolved_level_number := _clamp_level_number_for_track(track_key, level_number)
	var level_progress: Dictionary = _read_level_progress_dictionary(
		track_progress,
		resolved_level_number
	)
	if level_progress.is_empty():
		return

	level_progress[BOOK_LEVEL_COMPLETED_KEY] = true
	track_progress[resolved_level_number] = level_progress


func is_level_unlocked(track_key: String, level_number: int) -> bool:
	var resolved_level_number := _clamp_level_number_for_track(track_key, level_number)
	if resolved_level_number <= 1:
		return true
	return is_level_completed(track_key, resolved_level_number - 1)


func is_level_completed(track_key: String, level_number: int) -> bool:
	var track_progress := get_campaign_progress_for_track(track_key)
	if track_progress.is_empty():
		return false

	var resolved_level_number := _clamp_level_number_for_track(track_key, level_number)
	var level_progress: Dictionary = _read_level_progress_dictionary(
		track_progress,
		resolved_level_number
	)
	if level_progress.is_empty():
		return false

	return bool(level_progress.get(BOOK_LEVEL_COMPLETED_KEY, false))


# Persistencia y reanudacion del progreso.
func reset_progress() -> void:
	_progress_state_store.reset_progress()


func export_progress() -> Dictionary:
	return _progress_state_store.export_progress()


func import_progress(progress: Dictionary) -> void:
	_progress_state_store.import_progress(progress)


func get_progress_summary() -> Dictionary:
	return _progress_state_store.get_progress_summary()


func format_progress_summary_text(summary: Dictionary = {}) -> String:
	var summary_to_format := summary if not summary.is_empty() else get_progress_summary()
	var progress_lines: Array[String] = []
	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_progress_line := _build_track_progress_line(
			track_definition,
			summary_to_format
		)
		if track_progress_line.is_empty():
			continue
		progress_lines.append(track_progress_line)
	return "\n".join(progress_lines)


func get_progress_system_state(system_key: String) -> Dictionary:
	return _progress_state_store.get_progress_system_state(system_key)


func set_progress_system_state(system_key: String, system_state: Dictionary) -> void:
	_progress_state_store.set_progress_system_state(system_key, system_state)


func clear_progress_system_state(system_key: String) -> void:
	_progress_state_store.clear_progress_system_state(system_key)


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	return _progress_state_store.get_partial_level_state(track_key, level_number)


func set_partial_level_state(
	track_key: String,
	level_number: int,
	state: Dictionary
) -> void:
	_progress_state_store.set_partial_level_state(track_key, level_number, state)


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	_progress_state_store.clear_partial_level_state(track_key, level_number)


func _reset_runtime_progress_state() -> void:
	campaign_progress_by_track = build_default_campaign_progress_state()
	partial_level_state_by_track = _progress_state_store.build_empty_partial_level_state_map()
	progress_system_state_by_key = _progress_state_store.build_empty_progress_system_state_map()


func _build_track_progress_line(
	track_definition: Dictionary,
	progress_summary: Dictionary
) -> String:
	var track_key := str(track_definition.get("key", "")).strip_edges()
	if track_key.is_empty():
		return ""

	var level_count: int = get_track_level_count(track_key)
	var completed_level_count: int = int(progress_summary.get(track_key, 0))
	var visible_level_count := 0
	if level_count > 0:
		visible_level_count = min(level_count, completed_level_count + 1)

	var track_label := str(
		track_definition.get(
			"summary_label",
			track_definition.get("label", DEFAULT_PROGRESS_LABEL)
		)
	)
	return "%s %d/%d" % [track_label, visible_level_count, level_count]


func _resolve_existing_track_key(track_key: String) -> String:
	var normalized_track_key := track_key.strip_edges()
	if normalized_track_key.is_empty() or not GameTrackCatalog.has_track(normalized_track_key):
		return ""
	return normalized_track_key


func _ensure_track_progress_exists(track_key: String) -> void:
	if campaign_progress_by_track.has(track_key):
		return
	campaign_progress_by_track[track_key] = (
		_level_content_catalog.build_default_track_progress_for_track(track_key)
	)


func _read_track_progress_dictionary(track_key: String) -> Dictionary:
	var raw_track_progress: Variant = campaign_progress_by_track.get(track_key, {})
	return raw_track_progress if raw_track_progress is Dictionary else {}


func _read_level_progress_dictionary(
	track_progress: Dictionary,
	level_number: int
) -> Dictionary:
	var raw_level_progress: Variant = track_progress.get(level_number, {})
	return raw_level_progress if raw_level_progress is Dictionary else {}


func _clamp_level_number_for_track(track_key: String, level_number: int) -> int:
	var resolved_track_key: String = _resolve_existing_track_key(track_key)
	var max_level_number := get_max_track_level_count()
	if not resolved_track_key.is_empty():
		max_level_number = get_track_level_count(resolved_track_key)
	if max_level_number <= 0:
		return 1
	return clampi(level_number, 1, max_level_number)
