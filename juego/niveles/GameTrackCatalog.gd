extends RefCounted

# GameTrackCatalog.gd
# Catalogo estatico de pistas de la demo.
# Track = tema jugable; category = grupo usado para filtrar alimentos.

const LevelItemScript := preload("res://resources/level_item.gd")


# ─── Tracks ───────────────────────────────────────────────────────────────────

const TRACK_CELIAQUIA := "celiaquia"
const TRACK_VEGANISMO := "veganismo"
const TRACK_VEGANISMO_CELIAQUIA := "veganismo_celiaquia"
const TRACK_CETOGENICA := "cetogenica"

const ITEM_POOL_STRATEGY_CONDITIONS := "conditions"
const ITEM_POOL_STRATEGY_LEGACY := "legacy"

const DEFAULT_LEVEL_COUNT := 6

const TRACK_ORDER := [
	TRACK_CELIAQUIA,
	TRACK_VEGANISMO,
	TRACK_VEGANISMO_CELIAQUIA,
	TRACK_CETOGENICA
]

const TRACK_DEFINITIONS := {
	TRACK_CELIAQUIA: {
		"key": TRACK_CELIAQUIA,
		"label": "Celiaquía",
		"summary_label": "Celiaquía",
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
		"summary_label": "Veganismo + Celiaquía",
		"archive_texture_path": (
			"res://assets-sistema/interfaz/archivero-celiaquia-veganismo.png"
		),
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
		"item_pool_strategy": ITEM_POOL_STRATEGY_CONDITIONS,
		"blocked_conditions": [LevelItemScript.Condicion.KETO],
		"level_count": DEFAULT_LEVEL_COUNT
	}
}

const CATEGORY_ALMUERZO_CENA := "ALMCENA"
const CATEGORY_DESAYUNO_MERIENDA := "DESAMER"
const CATEGORY_BEBIDA := "BEBIDA"

const CATEGORY_DESAYUNO_MERIENDA_LEGACY := "DESAYMER"

const DEFAULT_CATEGORY_LABEL := "Categoria"

const CATEGORY_DEFINITIONS := {
	CATEGORY_ALMUERZO_CENA: {
		"code": CATEGORY_ALMUERZO_CENA,
		"label": "Almuerzo / Cena"
	},
	CATEGORY_DESAYUNO_MERIENDA: {
		"code": CATEGORY_DESAYUNO_MERIENDA,
		"label": "Desayuno / Merienda"
	},
	CATEGORY_BEBIDA: {
		"code": CATEGORY_BEBIDA,
		"label": "Bebida"
	}
}


static func obtener_claves_pista() -> Array:
	return TRACK_ORDER.duplicate()


static func tiene_pista(track_key: String) -> bool:
	return TRACK_DEFINITIONS.has(track_key.strip_edges())


static func obtener_definicion_pista(track_key: String) -> Dictionary:
	var key := track_key.strip_edges()
	if not TRACK_DEFINITIONS.has(key):
		return {}
	return (TRACK_DEFINITIONS[key] as Dictionary).duplicate(true)


static func obtener_etiqueta_pista(track_key: String, fallback: String = "") -> String:
	return str(obtener_definicion_pista(track_key).get("label", fallback)).strip_edges()


static func obtener_etiqueta_resumen_pista(track_key: String, fallback: String = "") -> String:
	return str(obtener_definicion_pista(track_key).get("summary_label", fallback)).strip_edges()


static func obtener_ruta_escena_libro(track_key: String) -> String:
	return str(obtener_definicion_pista(track_key).get("book_scene_path", "")).strip_edges()


static func obtener_ruta_escena_nivel(track_key: String) -> String:
	return str(obtener_definicion_pista(track_key).get("level_scene_path", "")).strip_edges()


static func obtener_ruta_textura_archivero(track_key: String) -> String:
	return str(obtener_definicion_pista(track_key).get("archive_texture_path", "")).strip_edges()


static func obtener_definiciones_pista() -> Array:
	var result: Array = []
	for track_key in TRACK_ORDER:
		result.append(obtener_definicion_pista(track_key))
	return result


static func obtener_pista_nivel_cantidad(track_key: String, fallback: int = DEFAULT_LEVEL_COUNT) -> int:
	var definition := obtener_definicion_pista(track_key)
	return max(1, int(definition.get("level_count", fallback)))


static func obtener_total_nivel_cantidad() -> int:
	var total := 0
	for track_key in TRACK_ORDER:
		total += obtener_pista_nivel_cantidad(track_key)
	return total


# ─── Helpers de categorias ────────────────────────────────────────────────────

static func normalizar_codigo_categoria(category_code: String) -> String:
	var clean := category_code.strip_edges().to_upper()
	if clean == CATEGORY_DESAYUNO_MERIENDA_LEGACY:
		return CATEGORY_DESAYUNO_MERIENDA
	return clean


static func obtener_etiqueta_categoria(
	category_code: String,
	fallback: String = DEFAULT_CATEGORY_LABEL
) -> String:
	var code := normalizar_codigo_categoria(category_code)
	if code.is_empty():
		return fallback
	var definition := CATEGORY_DEFINITIONS.get(code, {}) as Dictionary
	return str(definition.get("label", fallback))


static func categorias_coinciden(left_category: String, right_category: String) -> bool:
	return normalizar_codigo_categoria(left_category) == normalizar_codigo_categoria(right_category)
