extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

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

static var _texture_cache: Dictionary = {}


static func construir_rutas_activos_corrida(
	track_key: String,
	meal_key: String,
	teaching_key: String
) -> Dictionary:
	return {
		"meal_texture_path": obtener_ruta_textura_comida(meal_key),
		"condition_texture_path": obtener_ruta_textura_condicion_para_pista(track_key),
		"teaching_texture_path": obtener_ruta_textura_ensenanza(teaching_key)
	}


static func obtener_ruta_textura_comida(meal_key: String) -> String:
	return _buscar_ruta(MEAL_TEXTURE_PATHS, meal_key)


static func obtener_ruta_textura_condicion_para_pista(track_key: String) -> String:
	var track_definition := GameTrackCatalog.obtener_definicion_pista(track_key)
	return obtener_ruta_textura_condicion(
		str(track_definition.get("condition_texture_key", "")).strip_edges()
	)


static func obtener_ruta_textura_condicion(condition_key: String) -> String:
	return _buscar_ruta(CONDITION_TEXTURE_PATHS, condition_key)


static func obtener_ruta_textura_ensenanza(teaching_key: String) -> String:
	return _buscar_ruta(TEACHING_TEXTURE_PATHS, teaching_key)


static func resolver_textura(texture_ref: Variant) -> Texture2D:
	if texture_ref is Texture2D:
		return texture_ref
	var texture_path: String = str(texture_ref).strip_edges()
	if texture_path.is_empty():
		return null
	if _texture_cache.has(texture_path):
		return _texture_cache[texture_path]
	var texture: Texture2D = load(texture_path) as Texture2D
	_texture_cache[texture_path] = texture
	return texture


static func limpiar_cache_texturas() -> void:
	_texture_cache.clear()


static func _buscar_ruta(path_map: Dictionary, raw_key: String) -> String:
	var clean_key := raw_key.strip_edges().to_lower()
	if clean_key.is_empty():
		return ""
	return str(path_map.get(clean_key, ""))
