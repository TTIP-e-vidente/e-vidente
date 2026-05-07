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

static var _cache_texturas: Dictionary = {}


static func construir_rutas_activos_partida(
	track_key: String,
	meal_key: String,
	teaching_key: String
) -> Dictionary:
	var track_definition: Dictionary = GameTrackCatalog.obtener_definicion_pista(track_key)
	var condition_key: String = str(track_definition.get("condition_texture_key", "")).strip_edges()
	return {
		"meal_texture_path": _buscar_ruta(MEAL_TEXTURE_PATHS, meal_key),
		"condition_texture_path": _buscar_ruta(CONDITION_TEXTURE_PATHS, condition_key),
		"teaching_texture_path": _buscar_ruta(TEACHING_TEXTURE_PATHS, teaching_key)
	}


static func resolver_ruta_ensenanza_para_contexto(
	track_key: String,
	teaching_key: String,
	node_key: String = "",
	fallback_texture_path: String = ""
) -> String:
	var explicit_path: String = _resolver_ruta_ensenanza(teaching_key)
	if not explicit_path.is_empty():
		return explicit_path

	var inferred_key: String = _inferir_clave_ensenanza_desde_nodo(track_key, node_key)
	var inferred_path: String = _resolver_ruta_ensenanza(inferred_key)
	if not inferred_path.is_empty():
		return inferred_path

	var fallback_path: String = fallback_texture_path.strip_edges()
	if fallback_path.begins_with("res://assets-sistema/ensenanza/"):
		return fallback_path
	return ""


static func resolver_textura_ensenanza_para_contexto(
	track_key: String,
	teaching_key: String,
	node_key: String = "",
	fallback_texture_path: String = ""
) -> Texture2D:
	var texture_path: String = resolver_ruta_ensenanza_para_contexto(
		track_key,
		teaching_key,
		node_key,
		fallback_texture_path
	)
	if texture_path.is_empty():
		push_warning(
			"No se encontro asset de ensenanza para track='%s', teaching_key='%s', node_key='%s'."
			% [track_key, teaching_key, node_key]
		)
		return null
	var texture: Texture2D = resolver_textura(texture_path)
	if texture == null:
		push_warning("No se pudo cargar el asset de ensenanza: %s" % texture_path)
	return texture


static func resolver_textura(texture_ref: Variant) -> Texture2D:
	if texture_ref is Texture2D:
		return texture_ref
	var texture_path: String = str(texture_ref).strip_edges()
	if texture_path.is_empty():
		return null
	if _cache_texturas.has(texture_path):
		return _cache_texturas[texture_path]
	var texture: Texture2D = load(texture_path) as Texture2D
	_cache_texturas[texture_path] = texture
	return texture


static func limpiar_cache_texturas() -> void:
	_cache_texturas.clear()


static func _buscar_ruta(path_map: Dictionary, raw_key: String) -> String:
	var clean_key := raw_key.strip_edges().to_lower()
	if clean_key.is_empty():
		return ""
	return str(path_map.get(clean_key, ""))


static func _resolver_ruta_ensenanza(teaching_ref: String) -> String:
	var clean_ref: String = teaching_ref.strip_edges()
	if clean_ref.is_empty():
		return ""
	if clean_ref.begins_with("res://assets-sistema/ensenanza/"):
		return clean_ref
	return _buscar_ruta(TEACHING_TEXTURE_PATHS, clean_ref)


static func _inferir_clave_ensenanza_desde_nodo(track_key: String, node_key: String) -> String:
	var recipe_number: int = _extraer_numero_receta(node_key)
	if recipe_number <= 0:
		return ""

	var track_definition: Dictionary = GameTrackCatalog.obtener_definicion_pista(track_key)
	var raw_prefixes: Variant = track_definition.get("teaching_key_prefixes", [])
	if not raw_prefixes is Array or (raw_prefixes as Array).is_empty():
		return ""

	var prefix: String = str((raw_prefixes as Array)[0]).strip_edges()
	var inferred_key := "%s%d" % [prefix, recipe_number]
	return inferred_key if TEACHING_TEXTURE_PATHS.has(inferred_key) else ""


static func _extraer_numero_receta(node_key: String) -> int:
	var marker := "receta_"
	var start: int = node_key.find(marker)
	if start < 0:
		return 0
	var cursor: int = start + marker.length()
	var digits := ""
	while cursor < node_key.length():
		var character := node_key.substr(cursor, 1)
		if not character.is_valid_int():
			break
		digits += character
		cursor += 1
	return int(digits) if not digits.is_empty() else 0
