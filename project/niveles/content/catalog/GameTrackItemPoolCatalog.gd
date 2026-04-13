extends RefCounted


const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const ITEMS_DIR_PATH := "res://items"
const POSITIVE_ITEMS_KEY := "positive_items"
const NEGATIVE_ITEMS_KEY := "negative_items"

static var _cached_items: Array = []
static var _items_loaded := false


static func build_item_pool_for_track(
	track_key: String,
	legacy_positive_items: Array = [],
	legacy_negative_items: Array = []
) -> Dictionary:
	var track = track_key.strip_edges()
	if track.is_empty() or not GameTrackCatalog.has_track(track):
		return {
			POSITIVE_ITEMS_KEY: legacy_positive_items.duplicate(),
			NEGATIVE_ITEMS_KEY: legacy_negative_items.duplicate()
		}

	var legacy_positive_counts: Dictionary = _count_legacy_items_by_path(
		legacy_positive_items
	)
	var legacy_negative_counts: Dictionary = _count_legacy_items_by_path(
		legacy_negative_items
	)
	var positive_items: Array = []
	var negative_items: Array = []

	for item in get_all_items():
		if item == null:
			continue

		var item_group: String = classify_item_for_track(
			track,
			item,
			legacy_positive_counts,
			legacy_negative_counts
		)
		var item_path: String = _get_item_resource_path(item)

		if item_group == POSITIVE_ITEMS_KEY:
			var positive_count: int = int(legacy_positive_counts.get(item_path, 1))
			for unused_copy_index in range(max(1, positive_count)):
				positive_items.append(item)
			continue

		var negative_count: int = int(legacy_negative_counts.get(item_path, 1))
		for unused_copy_index in range(max(1, negative_count)):
			negative_items.append(item)

	return {
		POSITIVE_ITEMS_KEY: positive_items,
		NEGATIVE_ITEMS_KEY: negative_items
	}


static func classify_item_for_track(
	track_key: String,
	item: Variant,
	legacy_positive_counts: Dictionary = {},
	legacy_negative_counts: Dictionary = {}
) -> String:
	var track = track_key.strip_edges()
	if item == null or track.is_empty() or not GameTrackCatalog.has_track(track):
		return NEGATIVE_ITEMS_KEY

	if (
		item is Object
		and item.has_method("is_explicitly_blocked_for_track")
		and item.is_explicitly_blocked_for_track(track)
	):
		return NEGATIVE_ITEMS_KEY
	if (
		item is Object
		and item.has_method("is_explicitly_allowed_for_track")
		and item.is_explicitly_allowed_for_track(track)
	):
		return POSITIVE_ITEMS_KEY

	var item_path: String = _get_item_resource_path(item)
	var in_legacy_positive: bool = legacy_positive_counts.has(item_path)
	var in_legacy_negative: bool = legacy_negative_counts.has(item_path)
	if in_legacy_positive and not in_legacy_negative:
		return POSITIVE_ITEMS_KEY
	if in_legacy_negative and not in_legacy_positive:
		return NEGATIVE_ITEMS_KEY

	var track_definition: Dictionary = GameTrackCatalog.get_track_definition(track)
	var item_pool_strategy := str(
		track_definition.get(
			"item_pool_strategy",
			GameTrackCatalog.ITEM_POOL_STRATEGY_LEGACY
		)
	).strip_edges()
	if item_pool_strategy != GameTrackCatalog.ITEM_POOL_STRATEGY_CONDITIONS:
		return NEGATIVE_ITEMS_KEY
	if not (item is Object and item.has_method("has_any_condition")):
		return NEGATIVE_ITEMS_KEY

	var raw_blocked_conditions: Variant = track_definition.get("blocked_conditions", [])
	var blocked_conditions: Array = (
		raw_blocked_conditions if raw_blocked_conditions is Array else []
	)
	return (
		NEGATIVE_ITEMS_KEY
		if item.has_any_condition(blocked_conditions)
		else POSITIVE_ITEMS_KEY
	)


static func get_all_items() -> Array:
	if _items_loaded:
		return _cached_items.duplicate()
	_cached_items = _load_all_items()
	_items_loaded = true
	return _cached_items.duplicate()


static func _load_all_items() -> Array:
	var items: Array = []
	for item_path in _find_item_resource_paths():
		var item = load(item_path)
		if item == null:
			continue
		items.append(item)
	return items


static func _find_item_resource_paths() -> Array[String]:
	var dir := DirAccess.open(ITEMS_DIR_PATH)
	if dir == null:
		return []

	var item_paths: Array[String] = []
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		item_paths.append("%s/%s" % [ITEMS_DIR_PATH, file_name])
	dir.list_dir_end()
	item_paths.sort()
	return item_paths


static func _get_item_resource_path(item: Variant) -> String:
	return str((item as Resource).resource_path) if item is Resource else ""


static func _count_legacy_items_by_path(items: Array) -> Dictionary:
	var item_count_by_path: Dictionary = {}
	for item in items:
		if item == null:
			continue
		var item_path: String = _get_item_resource_path(item).strip_edges()
		if item_path.is_empty():
			continue
		item_count_by_path[item_path] = int(item_count_by_path.get(item_path, 0)) + 1
	return item_count_by_path
