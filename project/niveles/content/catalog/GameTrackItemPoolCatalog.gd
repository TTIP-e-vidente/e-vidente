extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const ITEMS_DIR_PATH := "res://items"
const POSITIVE_ITEMS_KEY := "positive_items"
const NEGATIVE_ITEMS_KEY := "negative_items"

static var _cached_items: Array = []
static var _items_loaded := false


static func construir_fondo_elemento_pista(
	track_key: String,
	legacy_positive_items: Array = [],
	legacy_negative_items: Array = []
) -> Dictionary:
	var clean_track_key: String = track_key.strip_edges()
	if clean_track_key.is_empty() or not GameTrackCatalog.tiene_pista(clean_track_key):
		return {
			POSITIVE_ITEMS_KEY: legacy_positive_items.duplicate(),
			NEGATIVE_ITEMS_KEY: legacy_negative_items.duplicate()
		}

	var conteos_positivos_legados: Dictionary = _contar_elementos_legados_por_ruta(
		legacy_positive_items
	)
	var conteos_negativos_legados: Dictionary = _contar_elementos_legados_por_ruta(
		legacy_negative_items
	)
	var pools: Dictionary = {
		POSITIVE_ITEMS_KEY: [],
		NEGATIVE_ITEMS_KEY: []
	}

	for item in obtener_todos_elementos():
		if item == null:
			continue

		var item_pool_key: String = clasificar_elemento_para_pista(
			clean_track_key,
			item,
			conteos_positivos_legados,
			conteos_negativos_legados
		)
		var item_path: String = _obtener_ruta_recurso_elemento(item)
		var copies: int = int(
			conteos_positivos_legados.get(item_path, 1)
			if item_pool_key == POSITIVE_ITEMS_KEY
			else conteos_negativos_legados.get(item_path, 1)
		)
		_agregar_copias(pools[item_pool_key], item, copies)

	return pools


static func clasificar_elemento_para_pista(
	track_key: String,
	item: Variant,
	legacy_positive_counts: Dictionary = {},
	legacy_negative_counts: Dictionary = {}
) -> String:
	var clean_track_key: String = track_key.strip_edges()
	if (
		item == null
		or clean_track_key.is_empty()
		or not GameTrackCatalog.tiene_pista(clean_track_key)
	):
		return NEGATIVE_ITEMS_KEY

	var explicit_item_group: String = _clasificar_elemento_por_reglas_pista_explicitas(
		clean_track_key,
		item
	)
	if not explicit_item_group.is_empty():
		return explicit_item_group

	var legacy_item_group: String = _clasificar_elemento_por_pertenencia_legada(
		item,
		legacy_positive_counts,
		legacy_negative_counts
	)
	if not legacy_item_group.is_empty():
		return legacy_item_group

	return _clasificar_elemento_usando_estrategia_pista(clean_track_key, item)
static func _clasificar_elemento_por_reglas_pista_explicitas(
	track_key: String,
	item: Variant
) -> String:
	if (
		item is Object
		and item.has_method("is_explicitly_blocked_for_track")
		and item.is_explicitly_blocked_for_track(track_key)
	):
		return NEGATIVE_ITEMS_KEY
	if (
		item is Object
		and item.has_method("is_explicitly_allowed_for_track")
		and item.is_explicitly_allowed_for_track(track_key)
	):
		return POSITIVE_ITEMS_KEY
	return ""


static func _clasificar_elemento_por_pertenencia_legada(
	item: Variant,
	legacy_positive_counts: Dictionary,
	legacy_negative_counts: Dictionary
) -> String:
	var item_path: String = _obtener_ruta_recurso_elemento(item)
	var is_in_legacy_positive_pool: bool = legacy_positive_counts.has(item_path)
	var is_in_legacy_negative_pool: bool = legacy_negative_counts.has(item_path)
	if is_in_legacy_positive_pool and not is_in_legacy_negative_pool:
		return POSITIVE_ITEMS_KEY
	if is_in_legacy_negative_pool and not is_in_legacy_positive_pool:
		return NEGATIVE_ITEMS_KEY
	return ""


static func _clasificar_elemento_usando_estrategia_pista(track_key: String, item: Variant) -> String:
	var track_definition: Dictionary = GameTrackCatalog.obtener_definicion_pista(track_key)
	var item_pool_strategy: String = str(
		track_definition.get(
			"item_pool_strategy",
			GameTrackCatalog.ITEM_POOL_STRATEGY_LEGACY
		)
	).strip_edges()
	if item_pool_strategy != GameTrackCatalog.ITEM_POOL_STRATEGY_CONDITIONS:
		return NEGATIVE_ITEMS_KEY
	if not (item is Object and item.has_method("has_any_condition")):
		return NEGATIVE_ITEMS_KEY

	var raw_blocked_conditions: Variant = track_definition.get("blocked_conditions", [])
	var blocked_conditions: Array = (
		raw_blocked_conditions if raw_blocked_conditions is Array else []
	)
	return (
		NEGATIVE_ITEMS_KEY
		if item.has_any_condition(blocked_conditions)
		else POSITIVE_ITEMS_KEY
	)
static func _agregar_copias(pool: Array, item: Variant, copies: int) -> void:
	for unused_index in range(max(1, copies)):
		pool.append(item)


static func obtener_todos_elementos() -> Array:
	if _items_loaded:
		return _cached_items.duplicate()
	_cached_items = _cargar_todos_elementos()
	_items_loaded = true
	return _cached_items.duplicate()


static func _cargar_todos_elementos() -> Array:
	var items: Array = []
	for item_path in _encontrar_rutas_recursos_elemento():
		var item = load(item_path)
		if item == null:
			continue
		items.append(item)
	return items


static func _encontrar_rutas_recursos_elemento() -> Array[String]:
	var dir = DirAccess.open(ITEMS_DIR_PATH)
	if dir == null:
		return []

	var item_paths: Array[String] = []
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		item_paths.append("%s/%s" % [ITEMS_DIR_PATH, file_name])
	dir.list_dir_end()
	item_paths.sort()
	return item_paths


static func _obtener_ruta_recurso_elemento(item: Variant) -> String:
	return str((item as Resource).resource_path) if item is Resource else ""


static func _contar_elementos_legados_por_ruta(items: Array) -> Dictionary:
	var item_count_by_path: Dictionary = {}
	for item in items:
		if item == null:
			continue
		var item_path: String = _obtener_ruta_recurso_elemento(item).strip_edges()
		if item_path.is_empty():
			continue
		item_count_by_path[item_path] = int(item_count_by_path.get(item_path, 0)) + 1
	return item_count_by_path
