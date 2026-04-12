extends RefCounted

const GameTrackChapterCatalog := preload(
	"res://niveles/helpers/catalog/GameTrackChapterDefinitions.gd"
)


static func get_meal_texture_path(meal_key: String) -> String:
	return GameTrackChapterCatalog.get_meal_texture_path(meal_key)


static func get_condition_texture_path(condition_key: String) -> String:
	return GameTrackChapterCatalog.get_condition_texture_path(condition_key)


static func get_teaching_texture_path(teaching_key: String) -> String:
	return GameTrackChapterCatalog.get_teaching_texture_path(teaching_key)
