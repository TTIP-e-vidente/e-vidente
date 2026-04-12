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
	var clean_track_key := _normalize_track_key(track_key)
	if clean_track_key.is_empty():
		return _build_legacy_fallback_pool(legacy_positive_items, legacy_negative_items)
	var legacy_positive_item_weights := _build_item_weight_index(legacy_positive_items)
	var legacy_negative_item_weights := _build_item_weight_index(legacy_negative_items)
	var positive_items: Array = []
	var negative_items: Array = []
	for item in get_all_items():
		if item == null:
			continue
		var classification := classify_item_for_track(
			clean_track_key,
			item,
			legacy_positive_item_weights,
			legacy_negative_item_weights
		)
		var item_path := _resolve_item_resource_path(item)
		match classification:
			POSITIVE_ITEMS_KEY:
				_append_weighted_items(
					positive_items,
					item,
					int(legacy_positive_item_weights.get(item_path, 1))
				)
			NEGATIVE_ITEMS_KEY:
				_append_weighted_items(
					negative_items,
					item,
					int(legacy_negative_item_weights.get(item_path, 1))
				)
	return {
		POSITIVE_ITEMS_KEY: positive_items,
		NEGATIVE_ITEMS_KEY: negative_items
	}


static func classify_item_for_track(
	track_key: String,
	item: Variant,
	legacy_positive_item_weights: Dictionary = {},
	legacy_negative_item_weights: Dictionary = {}
) -> String:
	var clean_track_key := _normalize_track_key(track_key)
	if item == null or clean_track_key.is_empty():
		return NEGATIVE_ITEMS_KEY
	var track_definition := GameTrackCatalog.get_track_definition(clean_track_key)
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

	var item_path := _resolve_item_resource_path(item)
	var in_legacy_positive := legacy_positive_item_weights.has(item_path)
	var in_legacy_negative := legacy_negative_item_weights.has(item_path)
	if in_legacy_positive and not in_legacy_negative:
		return POSITIVE_ITEMS_KEY
	if in_legacy_negative and not in_legacy_positive:
		return NEGATIVE_ITEMS_KEY

	var uses_condition_strategy := (
		str(
			track_definition.get(
				"item_pool_strategy",
				GameTrackCatalog.ITEM_POOL_STRATEGY_LEGACY
			)
		).strip_edges()
		== GameTrackCatalog.ITEM_POOL_STRATEGY_CONDITIONS
	)
	if not uses_condition_strategy:
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


static func _normalize_track_key(track_key: String) -> String:
	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty():
		return ""
	if not GameTrackCatalog.has_track(clean_track_key):
		return ""
	return clean_track_key


static func _build_legacy_fallback_pool(
	legacy_positive_items: Array,
	legacy_negative_items: Array
) -> Dictionary:
	return {
		POSITIVE_ITEMS_KEY: legacy_positive_items.duplicate(),
		NEGATIVE_ITEMS_KEY: legacy_negative_items.duplicate()
	}


static func _resolve_item_resource_path(item: Variant) -> String:
	return str((item as Resource).resource_path) if item is Resource else ""


static func _build_item_weight_index(items: Array) -> Dictionary:
	var item_weight_index: Dictionary = {}
	for item in items:
		if item == null:
			continue
		var item_path := _resolve_item_resource_path(item).strip_edges()
		if item_path.is_empty():
			continue
		item_weight_index[item_path] = int(item_weight_index.get(item_path, 0)) + 1
	return item_weight_index


static func _append_weighted_items(target_items: Array, item, weight: int) -> void:
	for unused_index in range(max(1, weight)):
		target_items.append(item)
