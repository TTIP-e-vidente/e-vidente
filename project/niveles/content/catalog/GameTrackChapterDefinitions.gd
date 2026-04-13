extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameChapterAssetCatalog := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

const CATEGORY_MEAL := GameTrackCatalog.CATEGORY_ALMUERZO_CENA
const CATEGORY_BREAKFAST := GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA
const CATEGORY_DRINK := GameTrackCatalog.CATEGORY_BEBIDA

const CHAPTERS_BY_TRACK := {
	GameTrackCatalog.TRACK_CELIAQUIA: [
		{
			"meal_key": "almuerzo",
			"teaching_key": "celiaquia_1",
			"category": CATEGORY_MEAL,
			"negative_count": 1,
			"positive_count": 1
		},
		{
			"meal_key": "desayuno",
			"teaching_key": "celiaquia_2",
			"category": CATEGORY_BREAKFAST,
			"negative_count": 2,
			"positive_count": 3
		},
		{
			"meal_key": "cena",
			"teaching_key": "celiaquia_6",
			"category": CATEGORY_MEAL,
			"negative_count": 2,
			"positive_count": 3
		},
		{
			"meal_key": "desayuno",
			"teaching_key": "celiaquia_8",
			"category": CATEGORY_BREAKFAST,
			"negative_count": 3,
			"positive_count": 3
		},
		{
			"meal_key": "almuerzo",
			"teaching_key": "celiaquia_5",
			"category": CATEGORY_MEAL,
			"negative_count": 4,
			"positive_count": 2
		},
		{
			"meal_key": "bebida",
			"teaching_key": "celiaquia_7",
			"category": CATEGORY_DRINK,
			"negative_count": 1,
			"positive_count": 3
		}
	],
	GameTrackCatalog.TRACK_VEGANISMO: [
		{
			"meal_key": "almuerzo",
			"teaching_key": "vegan_vegetariane_1",
			"category": CATEGORY_MEAL,
			"negative_count": 1,
			"positive_count": 2
		},
		{
			"meal_key": "desayuno",
			"teaching_key": "vegan_vegetariane_2",
			"category": CATEGORY_BREAKFAST,
			"negative_count": 2,
			"positive_count": 2
		},
		{
			"meal_key": "cena",
			"teaching_key": "vegan_vegetariane_3",
			"category": CATEGORY_MEAL,
			"negative_count": 2,
			"positive_count": 3
		},
		{
			"meal_key": "desayuno",
			"teaching_key": "vegan_vegetariane_4",
			"category": CATEGORY_BREAKFAST,
			"negative_count": 2,
			"positive_count": 4
		},
		{
			"meal_key": "almuerzo",
			"teaching_key": "vegan_vegetariane_5",
			"category": CATEGORY_MEAL,
			"negative_count": 4,
			"positive_count": 2
		},
		{
			"meal_key": "bebida",
			"teaching_key": "vegan_vegetariane_6",
			"category": CATEGORY_DRINK,
			"negative_count": 1,
			"positive_count": 3
		}
	],
	GameTrackCatalog.TRACK_VEGANISMO_CELIAQUIA: [
		{
			"meal_key": "almuerzo",
			"teaching_key": "celiaquia_3",
			"category": CATEGORY_MEAL,
			"negative_count": 1,
			"positive_count": 1
		},
		{
			"meal_key": "desayuno",
			"teaching_key": "vegan_vegetariane_7",
			"category": CATEGORY_BREAKFAST,
			"negative_count": 1,
			"positive_count": 2
		},
		{
			"meal_key": "cena",
			"teaching_key": "celiaquia_4",
			"category": CATEGORY_MEAL,
			"negative_count": 2,
			"positive_count": 4
		},
		{
			"meal_key": "desayuno",
			"teaching_key": "vegan_vegetariane_8",
			"category": CATEGORY_BREAKFAST,
			"negative_count": 4,
			"positive_count": 2
		},
		{
			"meal_key": "almuerzo",
			"teaching_key": "celiaquia_9",
			"category": CATEGORY_MEAL,
			"negative_count": 4,
			"positive_count": 2
		},
		{
			"meal_key": "bebida",
			"teaching_key": "celiaquia_7",
			"category": CATEGORY_DRINK,
			"negative_count": 2,
			"positive_count": 2
		}
	],
	GameTrackCatalog.TRACK_CETOGENICA: [
		{
			"meal_key": "almuerzo",
			"teaching_key": "keto_1",
			"category": CATEGORY_MEAL,
			"negative_count": 1,
			"positive_count": 1
		},
		{
			"meal_key": "desayuno",
			"teaching_key": "keto_2",
			"category": CATEGORY_BREAKFAST,
			"negative_count": 1,
			"positive_count": 2
		},
		{
			"meal_key": "cena",
			"teaching_key": "keto_3",
			"category": CATEGORY_MEAL,
			"negative_count": 2,
			"positive_count": 4
		},
		{
			"meal_key": "desayuno",
			"teaching_key": "keto_4",
			"category": CATEGORY_BREAKFAST,
			"negative_count": 4,
			"positive_count": 2
		},
		{
			"meal_key": "almuerzo",
			"teaching_key": "keto_5",
			"category": CATEGORY_MEAL,
			"negative_count": 4,
			"positive_count": 2
		},
		{
			"meal_key": "bebida",
			"teaching_key": "keto_6",
			"category": CATEGORY_DRINK,
			"negative_count": 2,
			"positive_count": 2
		}
	]
}


static func build_track_chapter_catalog() -> Dictionary:
	var chapters_by_track: Dictionary = {}
	for track_key in GameTrackCatalog.get_track_keys():
		var track_chapters: Dictionary = {}
		var raw_chapters: Variant = CHAPTERS_BY_TRACK.get(track_key, [])
		var chapter_list: Array = raw_chapters if raw_chapters is Array else []

		for chapter_index in range(chapter_list.size()):
			var raw_chapter_data: Variant = chapter_list[chapter_index]
			if not raw_chapter_data is Dictionary:
				continue

			var chapter_number: int = chapter_index + 1
			track_chapters[chapter_number] = {
				"runs": [_build_run_definition(track_key, raw_chapter_data)]
			}

		chapters_by_track[track_key] = track_chapters

	return chapters_by_track


static func _build_run_definition(track_key: String, chapter_data: Dictionary) -> Dictionary:
	var meal_key: String = str(chapter_data.get("meal_key", ""))
	var teaching_key: String = str(chapter_data.get("teaching_key", ""))
	var category: String = str(chapter_data.get("category", ""))
	var negative_count: int = int(chapter_data.get("negative_count", 0))
	var positive_count: int = int(chapter_data.get("positive_count", 0))
	var asset_paths: Dictionary = GameChapterAssetCatalog.build_run_asset_paths(
		track_key,
		meal_key,
		teaching_key
	)
	return {
		"mechanic_type": LevelMechanicTypes.PLATE_SORT,
		"mechanic_payload": {
			"negative_count": negative_count,
			"positive_count": positive_count,
			"category": category
		},
		"negative_count": negative_count,
		"positive_count": positive_count,
		"teaching_key": teaching_key,
		"meal_texture_path": str(asset_paths.get("meal_texture_path", "")),
		"condition_texture_path": str(asset_paths.get("condition_texture_path", "")),
		"teaching_texture_path": str(asset_paths.get("teaching_texture_path", "")),
		"category": category
	}
