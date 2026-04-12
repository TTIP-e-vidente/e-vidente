extends Resource
class_name LevelResource

const GameTrackItemPoolResolver := preload(
	"res://niveles/helpers/catalog/GameTrackItemPoolCatalog.gd"
)

@export var itemsPositivos : Array[LevelItem]
@export var itemsNegativos : Array[LevelItem]
@export var cantidadPositivos : int
@export var cantidadNegativos : int
@export var mechanic_type : String = ""
@export var mechanic_payload : Dictionary = {}
@export var comida : Texture2D
@export var condicion : Texture2D
@export var ensenanza : Texture2D

var _resolved_track_pools: Dictionary = {}


func get_positive_items(track_key: String = "") -> Array:
	return _get_track_pool(track_key).get(
		GameTrackItemPoolResolver.POSITIVE_ITEMS_KEY,
		itemsPositivos.duplicate()
	)


func get_negative_items(track_key: String = "") -> Array:
	return _get_track_pool(track_key).get(
		GameTrackItemPoolResolver.NEGATIVE_ITEMS_KEY,
		itemsNegativos.duplicate()
	)


func clear_track_pool_cache() -> void:
	_resolved_track_pools.clear()


func _get_track_pool(track_key: String) -> Dictionary:
	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty():
		return {
			GameTrackItemPoolResolver.POSITIVE_ITEMS_KEY: itemsPositivos.duplicate(),
			GameTrackItemPoolResolver.NEGATIVE_ITEMS_KEY: itemsNegativos.duplicate()
		}
	if not _resolved_track_pools.has(clean_track_key):
		_resolved_track_pools[clean_track_key] = (
			GameTrackItemPoolResolver.resolve_track_pools(
				clean_track_key,
				itemsPositivos,
				itemsNegativos
			)
		)
	return (_resolved_track_pools[clean_track_key] as Dictionary).duplicate(true)
