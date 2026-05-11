extends RefCounted

const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const ActivityAdapterScript := preload("res://sistemas/contenido/ActivityAdapter.gd")


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
