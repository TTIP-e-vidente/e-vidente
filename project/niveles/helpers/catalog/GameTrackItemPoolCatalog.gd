extends RefCounted


const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const ITEMS_DIR_PATH := "res://items"
const POSITIVE_ITEMS_KEY := "positive_items"
const NEGATIVE_ITEMS_KEY := "negative_items"

static var _cached_items: Array = []
static var _items_loaded := false


static func resolve_track_pools(
	track_key: String,
	legacy_positive_items: Array = [],
	legacy_negative_items: Array = []
) -> Dictionary:
	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty() or not GameTrackCatalog.has_track(clean_track_key):
		return {
			POSITIVE_ITEMS_KEY: legacy_positive_items.duplicate(),
			NEGATIVE_ITEMS_KEY: legacy_negative_items.duplicate()
		}

	var positive_items: Array = []
	var negative_items: Array = []
	var legacy_positive_weights := _count_items_by_path(legacy_positive_items)
	var legacy_negative_weights := _count_items_by_path(legacy_negative_items)
	for item in get_all_items():
		if item == null:
			continue
		var classification := classify_item_for_track(
			clean_track_key,
			item,
			legacy_positive_weights,
			legacy_negative_weights
		)
		match classification:
			POSITIVE_ITEMS_KEY:
				_append_weighted_item(
					positive_items,
					item,
					int(legacy_positive_weights.get(item.resource_path, 1))
				)
			NEGATIVE_ITEMS_KEY:
				_append_weighted_item(
					negative_items,
					item,
					int(legacy_negative_weights.get(item.resource_path, 1))
				)
	return {
		POSITIVE_ITEMS_KEY: positive_items,
		NEGATIVE_ITEMS_KEY: negative_items
	}


static func build_track_pools(
	track_key: String,
	legacy_positive_items: Array = [],
	legacy_negative_items: Array = []
) -> Dictionary:
	return resolve_track_pools(track_key, legacy_positive_items, legacy_negative_items)


static func resolve_item_classification(
	track_key: String,
	item: Variant,
	legacy_positive_weights: Dictionary = {},
	legacy_negative_weights: Dictionary = {}
) -> String:
	return _resolve_item_classification(
		track_key,
		item,
		legacy_positive_weights,
		legacy_negative_weights
	)


static func classify_item_for_track(
	track_key: String,
	item: Variant,
	legacy_positive_weights: Dictionary = {},
	legacy_negative_weights: Dictionary = {}
) -> String:
	return resolve_item_classification(
		track_key,
		item,
		legacy_positive_weights,
		legacy_negative_weights
	)


static func get_all_items() -> Array:
	if _items_loaded:
		return _cached_items.duplicate()
	_cached_items = _load_all_items()
	_items_loaded = true
	return _cached_items.duplicate()


static func _load_all_items() -> Array:
	var items: Array = []
	var item_file_paths: Array[String] = []
	var dir := DirAccess.open(ITEMS_DIR_PATH)
	if dir == null:
		return items
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		item_file_paths.append("%s/%s" % [ITEMS_DIR_PATH, file_name])
	dir.list_dir_end()
	item_file_paths.sort()
	for item_file_path in item_file_paths:
		var item = load(item_file_path)
		if item == null:
			continue
		items.append(item)
	return items


static func _resolve_item_classification(
	track_key: String,
	item: Variant,
	legacy_positive_weights: Dictionary,
	legacy_negative_weights: Dictionary
) -> String:
	if item == null:
		return NEGATIVE_ITEMS_KEY

	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty():
		return NEGATIVE_ITEMS_KEY

	if (
		item is Object
		and item.has_method("is_explicitly_blocked_for_track")
		and item.is_explicitly_blocked_for_track(clean_track_key)
	):
		return NEGATIVE_ITEMS_KEY
	if (
		item is Object
		and item.has_method("is_explicitly_allowed_for_track")
		and item.is_explicitly_allowed_for_track(clean_track_key)
	):
		return POSITIVE_ITEMS_KEY

	var item_path := str((item as Resource).resource_path) if item is Resource else ""
	var in_legacy_positive := legacy_positive_weights.has(item_path)
	var in_legacy_negative := legacy_negative_weights.has(item_path)
	if in_legacy_positive and not in_legacy_negative:
		return POSITIVE_ITEMS_KEY
	if in_legacy_negative and not in_legacy_positive:
		return NEGATIVE_ITEMS_KEY

	if (
		GameTrackCatalog.get_track_item_pool_strategy(clean_track_key)
		== GameTrackCatalog.ITEM_POOL_STRATEGY_CONDITIONS
	):
		if item is Object and item.has_method("has_any_condition"):
			return (
				NEGATIVE_ITEMS_KEY
				if item.has_any_condition(
					GameTrackCatalog.get_track_blocked_conditions(clean_track_key)
				)
				else POSITIVE_ITEMS_KEY
			)
		return NEGATIVE_ITEMS_KEY

	return NEGATIVE_ITEMS_KEY


static func _count_items_by_path(items: Array) -> Dictionary:
	var counts: Dictionary = {}
	for item in items:
		if item == null:
			continue
		var item_path := str(item.resource_path).strip_edges()
		if item_path.is_empty():
			continue
		counts[item_path] = int(counts.get(item_path, 0)) + 1
	return counts


static func _append_weighted_item(target_items: Array, item, weight: int) -> void:
	for unused_index in range(max(1, weight)):
		target_items.append(item)