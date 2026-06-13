extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const CargadorEnsenanzasScript := preload("res://ensenanzas/CargadorEnsenanzas.gd")
const LOG_PREFIX_TEACHING_ASSET := "[TeachingAsset]"

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

const TEACHING_KEY_TO_ASSET := {
	"celiaquia_desayuno": "res://assets-sistema/ensenanza/ensenanza-celiaquia-1.png",
	"celiaquia_colacion": "res://assets-sistema/ensenanza/ensenanza-celiaquia-2.png",
	"celiaquia_almuerzo": "res://assets-sistema/ensenanza/ensenanza-celiaquia-3.png",
	"celiaquia_cocina_segura": "res://assets-sistema/ensenanza/ensenanza-celiaquia-4.png",
	"celiaquia_merienda": "res://assets-sistema/ensenanza/ensenanza-celiaquia-5.png",
	"celiaquia_cena": "res://assets-sistema/ensenanza/ensenanza-celiaquia-6.png",
	"celiaquia_bebida": "res://assets-sistema/ensenanza/ensenanza-celiaquia-7.png",
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
		"teaching_texture_path": _resolver_ruta_ensenanza(teaching_key)
	}


static func resolver_ruta_ensenanza_para_contexto(
	track_key: String,
	teaching_key: String,
	node_key: String = "",
	fallback_texture_path: String = "",
	level_number: int = 0
) -> String:
	var requested_key: String = teaching_key.strip_edges().to_lower()
	var candidates: Array[String] = _build_teaching_candidates(
		track_key,
		teaching_key,
		node_key,
		fallback_texture_path,
		level_number
	)
	print("%s requested_key=%s" % [LOG_PREFIX_TEACHING_ASSET, requested_key])
	print(
		"%s candidates=%s"
		% [LOG_PREFIX_TEACHING_ASSET, _join_teaching_candidates(candidates)]
	)
	for candidate in candidates:
		var resolved_path: String = _resolver_ruta_ensenanza(candidate)
		if resolved_path.is_empty():
			continue
		print("%s found=true path=%s" % [LOG_PREFIX_TEACHING_ASSET, resolved_path])
		return resolved_path
	print("%s found=false" % LOG_PREFIX_TEACHING_ASSET)
	return ""


static func resolver_textura_ensenanza_para_contexto(
	track_key: String,
	teaching_key: String,
	node_key: String = "",
	fallback_texture_path: String = "",
	level_number: int = 0
) -> Texture2D:
	var texture_path: String = resolver_ruta_ensenanza_para_contexto(
		track_key,
		teaching_key,
		node_key,
		fallback_texture_path,
		level_number
	)
	if texture_path.is_empty():
		push_warning(
			(
				"No se encontro asset de ensenanza para track='%s',"
				+ " teaching_key='%s', node_key='%s', level_number=%d."
			)
			% [track_key, teaching_key, node_key, level_number]
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
	var json_path: String = CargadorEnsenanzasScript.resolver_ruta_imagen(clean_ref)
	if not json_path.is_empty() and _teaching_asset_exists(json_path):
		return json_path
	if clean_ref.begins_with("res://"):
		return clean_ref if _teaching_asset_exists(clean_ref) else ""
	var normalizado_ref: String = clean_ref.to_lower()
	var mapped_path: String = str(TEACHING_KEY_TO_ASSET.get(normalizado_ref, "")).strip_edges()
	if not mapped_path.is_empty():
		return mapped_path if _teaching_asset_exists(mapped_path) else ""
	var legacy_path: String = _buscar_ruta(TEACHING_TEXTURE_PATHS, normalizado_ref)
	if legacy_path.is_empty():
		return ""
	return legacy_path if _teaching_asset_exists(legacy_path) else ""


static func _build_teaching_candidates(
	track_key: String,
	teaching_key: String,
	node_key: String,
	fallback_texture_path: String,
	level_number: int
) -> Array[String]:
	var candidates: Array[String] = []
	_append_teaching_candidate(candidates, teaching_key)
	_append_teaching_candidate(
		candidates,
		_inferir_clave_ensenanza_desde_nodo(track_key, node_key)
	)
	_append_teaching_candidate(
		candidates,
		_inferir_clave_ensenanza_desde_numero(track_key, level_number)
	)
	_append_teaching_candidate(candidates, fallback_texture_path)
	return candidates


static func _append_teaching_candidate(candidates: Array[String], candidate: String) -> void:
	var clean_candidate: String = candidate.strip_edges()
	if clean_candidate.is_empty() or candidates.has(clean_candidate):
		return
	candidates.append(clean_candidate)


static func _join_teaching_candidates(candidates: Array[String]) -> String:
	var parts := PackedStringArray()
	for candidate in candidates:
		parts.append(candidate)
	return ",".join(parts)


static func _teaching_asset_exists(asset_path: String) -> bool:
	return ResourceLoader.exists(asset_path) or FileAccess.file_exists(asset_path)


static func _inferir_clave_ensenanza_desde_nodo(track_key: String, node_key: String) -> String:
	var recipe_number: int = _extraer_numero_receta(node_key)
	if recipe_number <= 0:
		return ""
	return _inferir_clave_ensenanza_desde_numero(track_key, recipe_number)


static func _inferir_clave_ensenanza_desde_numero(track_key: String, level_number: int) -> String:
	if level_number <= 0:
		return ""
	var track_definition: Dictionary = GameTrackCatalog.obtener_definicion_pista(track_key)
	var raw_prefixes: Variant = track_definition.get("teaching_key_prefixes", [])
	if not raw_prefixes is Array or (raw_prefixes as Array).is_empty():
		return ""

	var prefix: String = str((raw_prefixes as Array)[0]).strip_edges()
	var inferred_key := "%s%d" % [prefix, level_number]
	return inferred_key if TEACHING_TEXTURE_PATHS.has(inferred_key) else ""


static func _extraer_numero_receta(node_key: String) -> int:
	var clean_node_key: String = node_key.strip_edges().to_lower()
	var marker := "receta_"
	var start: int = clean_node_key.find(marker)
	if start < 0:
		for segment in clean_node_key.split("_", false):
			var clean_segment: String = str(segment).strip_edges()
			if clean_segment.is_valid_int():
				return int(clean_segment)
		return 0
	var cursor: int = start + marker.length()
	var digits := ""
	while cursor < clean_node_key.length():
		var character := clean_node_key.substr(cursor, 1)
		if not character.is_valid_int():
			break
		digits += character
		cursor += 1
	return int(digits) if not digits.is_empty() else 0
