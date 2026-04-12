extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

const CATEGORY_MEAL := GameTrackCatalog.CATEGORY_ALMUERZO_CENA
const CATEGORY_BREAKFAST := GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA
const CATEGORY_DRINK := GameTrackCatalog.CATEGORY_BEBIDA

const MEAL_TEXTURE_PATHS := {
	"desayuno": "res://assets-sistema/interfaz/desayuno.png",
	"almuerzo": "res://assets-sistema/interfaz/almuerzo.png",
	"cena": "res://assets-sistema/interfaz/cena.png",
	"bebida": "res://assets-sistema/interfaz/cena.png"
}

const CONDITION_TEXTURE_PATHS := {
	"prepara_celiaquia": "res://assets-sistema/interfaz/prepara-celiaquia.png",
	"prepara_vegane": "res://assets-sistema/interfaz/prepara-vegane.png",
	"prepara_vegan_gf": "res://assets-sistema/interfaz/prepara-vegan-gf.png",
	"prepara_keto": "res://assets-sistema/interfaz/prepara-keto.png"
}

const TEACHING_TEXTURE_PATHS := {
	"celiaquia_1": "res://assets-sistema/ensenanza/ensenanza-celiaquia-1.png",
	"celiaquia_2": "res://assets-sistema/ensenanza/ensenanza-celiaquia-2.png",
	"celiaquia_3": "res://assets-sistema/ensenanza/ensenanza-celiaquia-3.png",
	"celiaquia_4": "res://assets-sistema/ensenanza/ensenanza-celiaquia-4.png",
	"celiaquia_5": "res://assets-sistema/ensenanza/ensenanza-celiaquia-5.png",
	"celiaquia_6": "res://assets-sistema/ensenanza/ensenanza-celiaquia-6.png",
	"celiaquia_7": "res://assets-sistema/ensenanza/ensenanza-celiaquia-7.png",
	"celiaquia_8": "res://assets-sistema/ensenanza/ensenanza-celiaquia-8.png",
	"celiaquia_9": "res://assets-sistema/ensenanza/ensenanza-celiaquia-9.png",
	"vegan_vegetariane_1": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-1.png",
	"vegan_vegetariane_2": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-2.png",
	"vegan_vegetariane_3": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-3.png",
	"vegan_vegetariane_4": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-4.png",
	"vegan_vegetariane_5": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-5.png",
	"vegan_vegetariane_6": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-6.png",
	"vegan_vegetariane_7": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-7.png",
	"vegan_vegetariane_8": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-8.png",
	"keto_1": "res://assets-sistema/ensenanza/ensenanza-keto-1.png",
	"keto_2": "res://assets-sistema/ensenanza/ensenanza-keto-2.png",
	"keto_3": "res://assets-sistema/ensenanza/ensenanza-keto-3.png",
	"keto_4": "res://assets-sistema/ensenanza/ensenanza-keto-4.png",
	"keto_5": "res://assets-sistema/ensenanza/ensenanza-keto-5.png",
	"keto_6": "res://assets-sistema/ensenanza/ensenanza-keto-6.png"
}

const TRACK_CHAPTER_ROWS := {
	"celiaquia": [
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
	"veganismo": [
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
	"veganismo_celiaquia": [
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
	"cetogenica": [
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
	var definitions: Dictionary = {}
	for track_key in _catalog_track_keys():
		definitions[track_key] = _build_track_chapters(track_key)
	return definitions


static func build_track_chapter_definitions() -> Dictionary:
	return build_track_chapter_catalog()


static func _catalog_track_keys() -> Array:
	var track_keys: Array = GameTrackCatalog.get_track_keys().duplicate()
	for raw_track_key in TRACK_CHAPTER_ROWS.keys():
		var track_key: String = str(raw_track_key).strip_edges()
		if track_keys.has(track_key):
			continue
		track_keys.append(track_key)
	return track_keys


static func _build_track_chapters(track_key: String) -> Dictionary:
	var chapters: Dictionary = {}
	var raw_rows: Variant = TRACK_CHAPTER_ROWS.get(track_key, [])
	if not raw_rows is Array:
		return chapters
	var chapter_rows: Array = raw_rows
	for chapter_index in range(chapter_rows.size()):
		var chapter_row: Variant = chapter_rows[chapter_index]
		if not chapter_row is Dictionary:
			continue
		chapters[chapter_index + 1] = _build_chapter_definition(track_key, chapter_row)
	return chapters


static func _build_chapter_definition(track_key: String, chapter_row: Dictionary) -> Dictionary:
	var runs: Array = []
	for raw_run_row in _chapter_run_rows(chapter_row):
		if not raw_run_row is Dictionary:
			continue
		runs.append(_build_plate_sort_run(track_key, raw_run_row))
	return {"runs": runs}


static func _chapter_run_rows(chapter_row: Dictionary) -> Array:
	var raw_runs: Variant = chapter_row.get("runs", [])
	if raw_runs is Array and not raw_runs.is_empty():
		return (raw_runs as Array).duplicate(true)
	return [chapter_row.duplicate(true)]


static func _build_plate_sort_run(track_key: String, chapter_row: Dictionary) -> Dictionary:
	var meal_key: String = str(chapter_row.get("meal_key", ""))
	var teaching_key: String = str(chapter_row.get("teaching_key", ""))
	var category: String = str(chapter_row.get("category", ""))
	var negative_count: int = int(chapter_row.get("negative_count", 0))
	var positive_count: int = int(chapter_row.get("positive_count", 0))
	return {
		"mechanic_type": LevelMechanicTypes.PLATE_SORT,
		"mechanic_payload": _build_plate_sort_payload(negative_count, positive_count, category),
		"negative_count": negative_count,
		"positive_count": positive_count,
		"teaching_key": teaching_key,
		"meal_texture_path": get_meal_texture_path(meal_key),
		"condition_texture_path": get_condition_texture_path(
			_condition_key_for_track(track_key)
		),
		"teaching_texture_path": get_teaching_texture_path(teaching_key),
		"category": category
	}


static func _build_plate_sort_payload(
	negative_count: int,
	positive_count: int,
	category: String
) -> Dictionary:
	return {
		"negative_count": negative_count,
		"positive_count": positive_count,
		"category": category
	}


static func _condition_key_for_track(track_key: String) -> String:
	return GameTrackCatalog.get_track_condition_texture_key(track_key)


static func get_meal_texture_path(meal_key: String) -> String:
	return _lookup_path(MEAL_TEXTURE_PATHS, meal_key)


static func get_condition_texture_path(condition_key: String) -> String:
	return _lookup_path(CONDITION_TEXTURE_PATHS, condition_key)


static func get_teaching_texture_path(teaching_key: String) -> String:
	return _lookup_path(TEACHING_TEXTURE_PATHS, teaching_key)


static func _lookup_path(path_map: Dictionary, raw_key: String) -> String:
	var clean_key := raw_key.strip_edges().to_lower()
	if clean_key.is_empty():
		return ""
	return str(path_map.get(clean_key, ""))
