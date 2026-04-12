extends RefCounted

const LevelItemScript := preload("res://resources/level_item.gd")

const DEFAULT_LEVEL_COUNT := 6
const DEFAULT_CATEGORY_LABEL := "Categoria"

const TRACK_CELIAQUIA := "celiaquia"
const TRACK_VEGANISMO := "veganismo"
const TRACK_VEGANISMO_CELIAQUIA := "veganismo_celiaquia"
const TRACK_CETOGENICA := "cetogenica"

const CATEGORY_ALMUERZO_CENA := "ALMCENA"
const CATEGORY_DESAYUNO_MERIENDA := "DESAMER"
const CATEGORY_DESAYUNO_MERIENDA_LEGACY := "DESAYMER"
const CATEGORY_BEBIDA := "BEBIDA"
const ITEM_POOL_STRATEGY_CONDITIONS := "conditions"
const ITEM_POOL_STRATEGY_LEGACY := "legacy"
const TRACK_ORDER := [
	TRACK_CELIAQUIA,
	TRACK_VEGANISMO,
	TRACK_VEGANISMO_CELIAQUIA,
	TRACK_CETOGENICA
]

const TRACK_DEFINITIONS := {
	TRACK_CELIAQUIA: {
		"key": TRACK_CELIAQUIA,
		"label": "Celiaquia",
		"summary_label": "Celiaquia",
		"archive_texture_path": "res://assets-sistema/interfaz/archivero-celiaquia.png",
		"condition_texture_key": "prepara_celiaquia",
		"teaching_key_prefixes": ["celiaquia_"],
		"book_scene_path": "res://interface/libro.tscn",
		"level_scene_path": "res://niveles/nivel_1/Level.tscn",
		"item_pool_strategy": ITEM_POOL_STRATEGY_CONDITIONS,
		"blocked_conditions": [LevelItemScript.Condicion.CELIACO],
		"level_count": DEFAULT_LEVEL_COUNT
	},
	TRACK_VEGANISMO: {
		"key": TRACK_VEGANISMO,
		"label": "Veganismo",
		"summary_label": "Veganismo",
		"archive_texture_path": "res://assets-sistema/interfaz/archivero-veganismo.png",
		"condition_texture_key": "prepara_vegane",
		"teaching_key_prefixes": ["vegan_vegetariane_"],
		"book_scene_path": "res://interface/libro-vegan.tscn",
		"level_scene_path": "res://niveles/nivel_2/level_vegan.tscn",
		"item_pool_strategy": ITEM_POOL_STRATEGY_CONDITIONS,
		"blocked_conditions": [
			LevelItemScript.Condicion.VEGANO,
			LevelItemScript.Condicion.VEGETARIANO
		],
		"level_count": DEFAULT_LEVEL_COUNT
	},
	TRACK_VEGANISMO_CELIAQUIA: {
		"key": TRACK_VEGANISMO_CELIAQUIA,
		"label": "Veganismo + Celiaquia",
		"summary_label": "Mixto",
		"archive_texture_path": "res://assets-sistema/interfaz/archivero-celiaquia-veganismo.png",
		"condition_texture_key": "prepara_vegan_gf",
		"teaching_key_prefixes": ["celiaquia_", "vegan_vegetariane_"],
		"book_scene_path": "res://interface/Libro-Vegan-GF.tscn",
		"level_scene_path": "res://niveles/nivel_3/Level-Vegan-GF.tscn",
		"item_pool_strategy": ITEM_POOL_STRATEGY_CONDITIONS,
		"blocked_conditions": [
			LevelItemScript.Condicion.CELIACO,
			LevelItemScript.Condicion.VEGANO,
			LevelItemScript.Condicion.VEGETARIANO
		],
		"level_count": DEFAULT_LEVEL_COUNT
	},
	TRACK_CETOGENICA: {
		"key": TRACK_CETOGENICA,
		"label": "Cetogenica",
		"summary_label": "Keto",
		"archive_texture_path": "res://assets-sistema/interfaz/archivero-keto.png",
		"condition_texture_key": "prepara_keto",
		"teaching_key_prefixes": ["keto_"],
		"book_scene_path": "res://interface/Libro-Keto.tscn",
		"level_scene_path": "res://niveles/nivel_4/Level-Keto.tscn",
		"item_pool_strategy": ITEM_POOL_STRATEGY_LEGACY,
		"blocked_conditions": [],
		"level_count": DEFAULT_LEVEL_COUNT
	}
}

const CATEGORY_DEFINITIONS := {
	CATEGORY_ALMUERZO_CENA: {
		"code": CATEGORY_ALMUERZO_CENA,
		"label": "Almuerzo / Cena"
	},
	CATEGORY_DESAYUNO_MERIENDA: {
		"code": CATEGORY_DESAYUNO_MERIENDA,
		"label": "Desayuno / Merienda"
	},
	CATEGORY_BEBIDA: {"code": CATEGORY_BEBIDA, "label": "Bebida"}
}


static func get_track_keys() -> Array:
	return TRACK_ORDER.duplicate()


static func get_track_definitions() -> Array:
	var definitions: Array = []
	for track_key in TRACK_ORDER:
		definitions.append((TRACK_DEFINITIONS[track_key] as Dictionary).duplicate(true))
	return definitions


static func has_track(track_key: String) -> bool:
	return TRACK_DEFINITIONS.has(_normalize_track_key(track_key))


static func get_track_definition(track_key: String) -> Dictionary:
	var clean_track_key := _normalize_track_key(track_key)
	if not TRACK_DEFINITIONS.has(clean_track_key):
		return {}
	return (TRACK_DEFINITIONS[clean_track_key] as Dictionary).duplicate(true)


static func get_track_level_count(track_key: String, fallback: int = DEFAULT_LEVEL_COUNT) -> int:
	var track_definition := get_track_definition(track_key)
	return max(1, int(track_definition.get("level_count", fallback)))


static func get_total_level_count() -> int:
	var total_levels := 0
	for track_definition in get_track_definitions():
		total_levels += max(
			1,
			int(track_definition.get("level_count", DEFAULT_LEVEL_COUNT))
		)
	return total_levels


static func get_category_label(
	category_code: String,
	fallback: String = DEFAULT_CATEGORY_LABEL
) -> String:
	var clean_category_code := normalize_category_code(category_code)
	if not CATEGORY_DEFINITIONS.has(clean_category_code):
		return fallback
	return str(
		(CATEGORY_DEFINITIONS[clean_category_code] as Dictionary).get("label", fallback)
	)


static func normalize_category_code(category_code: String) -> String:
	var clean_category_code := category_code.strip_edges().to_upper()
	match clean_category_code:
		CATEGORY_DESAYUNO_MERIENDA_LEGACY:
			return CATEGORY_DESAYUNO_MERIENDA
		_:
			return clean_category_code


static func categories_match(left_category: String, right_category: String) -> bool:
	return normalize_category_code(left_category) == normalize_category_code(right_category)


static func _normalize_track_key(track_key: String) -> String:
	return track_key.strip_edges()