extends Resource
class_name LevelResource

const GameTrackItemPoolCatalogScript := preload(
	"res://niveles/content/catalog/GameTrackItemPoolCatalog.gd"
)

@export var itemsPositivos: Array = []
@export var itemsNegativos: Array = []
@export var cantidadPositivos : int
@export var cantidadNegativos : int
@export var mechanic_type : String = ""
@export var mechanic_payload : Dictionary = {}
@export var comida : Texture2D
@export var condicion : Texture2D
@export var ensenanza : Texture2D

var _resolved_track_pools: Dictionary = {}


func get_positive_items(track_key: String = "") -> Array:
	return _get_track_pool_items(
		track_key,
		GameTrackItemPoolCatalogScript.POSITIVE_ITEMS_KEY,
		itemsPositivos
	)


func get_negative_items(track_key: String = "") -> Array:
	return _get_track_pool_items(
		track_key,
		GameTrackItemPoolCatalogScript.NEGATIVE_ITEMS_KEY,
		itemsNegativos
	)


func clear_track_pool_cache() -> void:
	_resolved_track_pools.clear()


func _get_track_pool_items(
	track_key: String,
	pool_key: String,
	fallback_items: Array
) -> Array:
	return _get_track_pool(track_key).get(pool_key, fallback_items.duplicate())


func _get_track_pool(track_key: String) -> Dictionary:
	var clean_track_key: String = track_key.strip_edges()
	if clean_track_key.is_empty():
		return _build_default_track_pool()
	return _get_or_build_cached_track_pool(clean_track_key)


func _build_default_track_pool() -> Dictionary:
	return {
		GameTrackItemPoolCatalogScript.POSITIVE_ITEMS_KEY: itemsPositivos.duplicate(),
		GameTrackItemPoolCatalogScript.NEGATIVE_ITEMS_KEY: itemsNegativos.duplicate()
	}


func _get_or_build_cached_track_pool(track_key: String) -> Dictionary:
	if not _resolved_track_pools.has(track_key):
		_resolved_track_pools[track_key] = _build_track_pool_for_track(track_key)
	return (_resolved_track_pools[track_key] as Dictionary).duplicate(true)


func _build_track_pool_for_track(track_key: String) -> Dictionary:
	return GameTrackItemPoolCatalogScript.build_item_pool_for_track(
		track_key,
		itemsPositivos,
		itemsNegativos
	)
