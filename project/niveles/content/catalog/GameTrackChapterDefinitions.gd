extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameChapterAssetCatalog := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const PLATE_SORT_MECHANIC_TYPE := "plate_sort"

const CATEGORY_MEAL := GameTrackCatalog.CATEGORY_ALMUERZO_CENA
const CATEGORY_BREAKFAST := GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA
const CATEGORY_DRINK := GameTrackCatalog.CATEGORY_BEBIDA

const RAW_CHAPTERS_BY_TRACK := {
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
			"teaching_key": "w_1",
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


static func construir_catalogo_capitulo_pista() -> Dictionary:
	var chapters_by_track: Dictionary = {}
	for track_key in GameTrackCatalog.obtener_claves_pista():
		chapters_by_track[track_key] = _construir_capitulos_de_pista(track_key)

	return chapters_by_track


static func _construir_capitulos_de_pista(track_key: String) -> Dictionary:
	var capitulos: Dictionary = {}
	var raw_chapters: Variant = RAW_CHAPTERS_BY_TRACK.get(track_key, [])
	var chapter_list: Array = raw_chapters if raw_chapters is Array else []

	for chapter_index in range(chapter_list.size()):
		var raw_chapter_definition: Variant = chapter_list[chapter_index]
		if not raw_chapter_definition is Dictionary:
			continue
		capitulos[chapter_index + 1] = {
			"runs": [_construir_partida(track_key, raw_chapter_definition as Dictionary)]
		}

	return capitulos


static func _construir_partida(track_key: String, chapter_definition: Dictionary) -> Dictionary:
	var meal_key: String = str(chapter_definition.get("meal_key", "")).strip_edges()
	var teaching_key: String = str(chapter_definition.get("teaching_key", "")).strip_edges()
	var category: String = str(chapter_definition.get("category", "")).strip_edges()
	var negative_count: int = int(chapter_definition.get("negative_count", 0))
	var positive_count: int = int(chapter_definition.get("positive_count", 0))
	var asset_paths: Dictionary = GameChapterAssetCatalog.construir_rutas_activos_partida(
		track_key,
		meal_key,
		teaching_key
	)

	return {
		"mechanic_type": PLATE_SORT_MECHANIC_TYPE,
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
