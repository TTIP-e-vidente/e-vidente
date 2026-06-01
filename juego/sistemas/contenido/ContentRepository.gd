extends RefCounted
class_name ContentRepository

const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const ActivityAdapterScript := preload("res://sistemas/contenido/ActivityAdapter.gd")
const ContentIdValidatorScript := preload("res://sistemas/contenido/ContentIdValidator.gd")


static func cargar_contenido(context: Dictionary) -> Dictionary:
	return NodeContentLoaderScript.load_from_context(context)


static func get_activity(pack_id: String, activity_id: String) -> Dictionary:
	return NodeContentLoaderScript.get_activity(pack_id, activity_id)


static func get_candidates(
	track_key: String,
	activity_type: String,
	difficulty: int,
	options_count: int = 0
) -> Array[String]:
	return NodeContentLoaderScript.get_activity_candidates(
		track_key,
		activity_type,
		difficulty,
		options_count
	)


static func get_candidates_near(
	track_key: String,
	activity_type: String,
	difficulty: int,
	options_count: int = 0
) -> Array[String]:
	return NodeContentLoaderScript.get_activity_candidates_near(
		track_key,
		activity_type,
		difficulty,
		options_count
	)


static func adapt_activity(
	activity: Dictionary,
	pack_id: String = "",
	options: Dictionary = {}
) -> Dictionary:
	return ActivityAdapterScript.to_legacy_node(activity, pack_id, {}, options)


## Devuelve solo los ítems de all_content cuyo "id" no está en completed_ids.
## Útil para filtrar el pool de actividades antes de seleccionar la siguiente.
static func filter_uncompleted_content(
	all_content: Array,
	completed_ids: Array[String]
) -> Array:
	return ContentIdValidatorScript.filter_uncompleted(all_content, completed_ids)
