extends RefCounted
class_name NodeContentLoader

const ActivityAdapterScript := preload("res://sistemas/contenido/ActivityAdapter.gd")
const ContentIdValidatorScript := preload("res://sistemas/contenido/ContentIdValidator.gd")
const LegacyNodeLoaderScript := preload("res://sistemas/contenido/CargadorDeContenidoDeNodo.gd")

const MODE_QUIZ_CHOICE := LegacyNodeLoaderScript.MODE_QUIZ_CHOICE
const MODE_DRAG_DROP := LegacyNodeLoaderScript.MODE_DRAG_DROP
const MODE_VINCULACION_CONCEPTOS := LegacyNodeLoaderScript.MODE_VINCULACION_CONCEPTOS

const PACK_PATH_BY_ID := {
	"celiaquia": "res://contenido/packs/celiaquia_pack.json",
}
const MAPA_DIR_BY_TRACK := {
	"celiaquia": "res://contenido/mapa/",
}
const ITEMS_CELIAQUIA_PATH := "res://contenido/catalogos/items_celiaquia.json"
const DEFAULT_PACK_ID := "celiaquia"
const LOG_PREFIX_CONTENT_MAP := "[ContentMap]"
const LOG_PREFIX_CONTENT_MAP_ERROR := "[ContentMapError]"
const LOG_PREFIX_ACTIVITY_MODE := "[ActivityMode]"
const CATEGORY_SAFE := "sin_tacc"
const VALID_CATEGORIES := ["sin_tacc", "con_gluten", "riesgo"]
const VALID_MEALS := [
	"desayuno",
	"merienda",
	"colacion",
	"almuerzo",
	"cena",
	"bebida",
	"cocina_segura",
]

static var _default_pack_warning_shown := false
static var _pack_cache: Dictionary = {}
static var _items_catalog_cache: Dictionary = {}


static func cargar_desde_contexto(context: Dictionary) -> Dictionary:
	var _node_key: String = str(
		context.get("node_key", context.get("clave_nodo_de_origen", ""))
	).strip_edges()
	var activity_id: String = str(context.get("activity_id", "")).strip_edges()
	if not activity_id.is_empty():
		var pack_id: String = _resolve_pack_id(
			str(context.get("pack_id", "")).strip_edges(),
			str(context.get("track_key", "")).strip_edges()
		)
		var pack_result: Dictionary = load_from_pack(pack_id, activity_id, context)
		if bool(pack_result.get("ok", false)):
			return pack_result
		if not str(context.get("json_path", "")).strip_edges().is_empty():
			push_warning(
				"%s activity=%s fallback=legacy_json error=%s"
				% [LOG_PREFIX_CONTENT_MAP, activity_id, str(pack_result.get("error", ""))]
			)
			var fallback_path: String = str(context.get("json_path", "")).strip_edges()
			return LegacyNodeLoaderScript.cargar_contenido_nodo(fallback_path)
		return pack_result

	var json_path: String = str(context.get("json_path", "")).strip_edges()
	if json_path.is_empty():
		return _error("El nodo no tiene activity_id ni json_path.")
	return LegacyNodeLoaderScript.cargar_contenido_nodo(json_path)


static func load_from_pack(
	pack_id: String,
	activity_id: String,
	options: Dictionary = {}
) -> Dictionary:
	var activity_result: Dictionary = cargar_actividad(pack_id, activity_id)
	if not bool(activity_result.get("ok", false)):
		return _error(str(activity_result.get("error", "No se pudo cargar la activity.")))

	var activity: Dictionary = activity_result.get("data", {})
	var pack: Dictionary = activity_result.get("pack", {})
	var adapter_options := {
		"difficulty": int(
			options.get("difficulty", options.get("dificultad", activity.get("difficulty", 1)))
		),
	}
	if options.has("seed"):
		adapter_options["seed"] = int(options.get("seed", 0))
	var adapted: Dictionary = ActivityAdapterScript.a_nodo_legado(
		activity,
		pack_id,
		pack,
		adapter_options
	)
	if adapted.is_empty():
		return _error("No se pudo adaptar activity_id: %s" % activity_id)

	return {
		"ok": true,
		"error": "",
		"data": adapted,
		"source": "content_pack",
		"activity_mode": str(activity.get("mode", "")).strip_edges(),
	}


static func load_pack(pack_id: String) -> Dictionary:
	var clean_pack_id: String = _resolve_pack_id(pack_id)
	if _pack_cache.has(clean_pack_id):
		return {"ok": true, "error": "", "data": _pack_cache[clean_pack_id], "path": "cache"}

	var mapa_dir: String = str(MAPA_DIR_BY_TRACK.get(clean_pack_id, "")).strip_edges()
	if not mapa_dir.is_empty():
		var result: Dictionary = _load_mapa_pack(clean_pack_id, mapa_dir)
		if result.get("ok", false):
			_pack_cache[clean_pack_id] = result.get("data", {})
		return result

	var pack_path: String = str(PACK_PATH_BY_ID.get(clean_pack_id, "")).strip_edges()
	if pack_path.is_empty():
		return _error("No hay Content Pack registrado para: %s" % clean_pack_id)

	var file := FileAccess.open(pack_path, FileAccess.READ)
	if file == null:
		return _error("No se pudo abrir el Content Pack: %s" % pack_path)

	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	if parse_result != OK:
		return _error(
			"Content Pack invalido en %s linea %d: %s"
			% [pack_path, parser.get_error_line(), parser.get_error_message()]
		)

	var parsed: Variant = parser.get_data()
	if not parsed is Dictionary:
		return _error("El Content Pack debe ser un objeto: %s" % pack_path)

	var pack: Dictionary = parsed as Dictionary
	var validation_error: String = _validar_pack_minimal(pack, pack_path)
	if not validation_error.is_empty():
		return _error("Content Pack %s invalido: %s" % [clean_pack_id, validation_error])
	_pack_cache[clean_pack_id] = pack
	return {"ok": true, "error": "", "data": pack, "path": pack_path}


static func cargar_actividad(pack_id: String, activity_id: String) -> Dictionary:
	var resolved_pack_id: String = _resolve_pack_id(pack_id)
	var pack_result: Dictionary = load_pack(resolved_pack_id)
	if not bool(pack_result.get("ok", false)):
		return pack_result

	var pack: Dictionary = pack_result.get("data", {})
	var activity: Dictionary = _obtener_actividad_from_pack(pack, activity_id)
	if activity.is_empty():
		print(
			"%s missing activity=%s source=%s"
			% [
				LOG_PREFIX_CONTENT_MAP_ERROR,
				activity_id.strip_edges(),
				_guess_source_file_for_activity_id(activity_id),
			]
		)
		return _error(
			"Content Pack %s no contiene activity_id: %s"
			% [resolved_pack_id, activity_id.strip_edges()]
		)

	print(
		"%s activity=%s mode=%s"
		% [
			LOG_PREFIX_CONTENT_MAP,
			activity_id.strip_edges(),
			str(activity.get("mode", "")).strip_edges(),
		]
	)

	return {
		"ok": true,
		"error": "",
		"data": activity,
		"pack": pack,
		"path": str(pack_result.get("path", "")),
	}


static func obtener_actividad(pack_id: String, activity_id: String) -> Dictionary:
	var result: Dictionary = cargar_actividad(pack_id, activity_id)
	if not bool(result.get("ok", false)):
		return {}
	return (result.get("data", {}) as Dictionary).duplicate(true)


static func has_activity(pack_id: String, activity_id: String) -> Dictionary:
	var result: Dictionary = cargar_actividad(_resolve_pack_id(pack_id), activity_id)
	if bool(result.get("ok", false)):
		return {"ok": true, "error": ""}
	return {"ok": false, "error": str(result.get("error", ""))}


static func to_runtime_mode(raw_mode: String) -> String:
	print("TO_RUNTIME_MODE:", raw_mode)

	match raw_mode.strip_edges():
		"quiz":
			return "quiz_choice"

		"drag", "drag_food":
			return "drag_drop"

		"match":
			return "vinculacion_conceptos"

		"completar_palabra":
			return "completar_palabra"

		_:
			print("NO MATCH:", raw_mode)
			return ""


static func _obtener_actividad_from_pack(pack: Dictionary, activity_id: String) -> Dictionary:
	var clean_activity_id: String = activity_id.strip_edges()
	for raw_activity in pack.get("activities", []):
		if raw_activity is Dictionary:
			var activity: Dictionary = raw_activity as Dictionary
			if str(activity.get("id", "")).strip_edges() == clean_activity_id:
				return activity.duplicate(true)
	return {}


static func normalizar_random_game_type(raw_type: String) -> String:
	match raw_type.strip_edges().to_lower():
		"drag", "drag_food":
			return "drag"
		"quiz":
			return "quiz"
		"match", "vinculacion":
			return "match"
		"completar_palabra":
			return "completar_palabra"
		_:
			return ""


static func obtener_candidatos_actividad(
	track_key: String,
	requested_type: String,
	requested_difficulty: int,
	requested_options_count: int = 0
) -> Array[String]:
	var normalizado_type: String = normalizar_random_game_type(requested_type)

	if normalizado_type.is_empty() or requested_difficulty <= 0:
		return []

	var pack_result: Dictionary = load_pack(track_key)

	if not bool(pack_result.get("ok", false)):
		return []

	var pack: Dictionary = pack_result.get("data", {})
	var activity_candidates: Array[String] = []

	for raw_activity in pack.get("activities", []):
		if not raw_activity is Dictionary:
			continue

		var activity: Dictionary = raw_activity as Dictionary

		if not _activity_matches_requested_type(activity, normalizado_type):
			continue

		if int(activity.get("difficulty", 0)) != requested_difficulty:
			continue

		if not _activity_matches_requested_options_count(
			activity,
			normalizado_type,
			requested_options_count
		):
			continue

		var activity_id: String = str(activity.get("id", "")).strip_edges()

		if not activity_id.is_empty():
			activity_candidates.append(activity_id)

	return activity_candidates


static func obtener_candidatos_actividad_near(
	track_key: String,
	requested_type: String,
	requested_difficulty: int,
	requested_options_count: int = 0
) -> Array[String]:
	var ordered_difficulties: Array[int] = _ordered_requested_difficulties(requested_difficulty)
	var activity_candidates: Array[String] = []
	for candidate_difficulty in ordered_difficulties:
		for activity_id in obtener_candidatos_actividad(
			track_key,
			requested_type,
			candidate_difficulty,
			requested_options_count
		):
			if not activity_candidates.has(activity_id):
				activity_candidates.append(activity_id)
	return activity_candidates


static func _ordered_requested_difficulties(requested_difficulty: int) -> Array[int]:
	var ordered_difficulties: Array[int] = []
	if requested_difficulty >= 1 and requested_difficulty <= 3:
		ordered_difficulties.append(requested_difficulty)
	for lower_difficulty in range(requested_difficulty - 1, 0, -1):
		ordered_difficulties.append(lower_difficulty)
	for higher_difficulty in range(requested_difficulty + 1, 4):
		ordered_difficulties.append(higher_difficulty)
	return ordered_difficulties


static func _activity_matches_requested_type(activity: Dictionary, requested_type: String) -> bool:
	match normalizar_random_game_type(requested_type):
		"drag":
			return ["drag", "drag_food"].has(str(activity.get("mode", "")).strip_edges())
		"quiz":
			return str(activity.get("mode", "")).strip_edges() == "quiz"
		"match":
			return str(activity.get("mode", "")).strip_edges() == "match"
		"completar_palabra":
			return str(activity.get("mode", "")).strip_edges() == "completar_palabra"
		_:
			return false


static func _activity_matches_requested_options_count(
	activity: Dictionary,
	normalizado_type: String,
	requested_options_count: int
) -> bool:
	if requested_options_count <= 0 or normalizado_type != "quiz":
		return true
	var options: Variant = activity.get("options", [])
	if not options is Array:
		return false
	return (options as Array).size() == requested_options_count


static func _validar_pack_minimal(pack: Dictionary, pack_path: String = "") -> String:
	var errors: Array[String] = []
	if str(pack.get("id", "")).strip_edges().is_empty():
		errors.append("falta id.")
	if int(pack.get("version", 0)) <= 0:
		errors.append("falta version valida.")
	if not pack.get("activities", []) is Array:
		errors.append("activities debe ser array.")
		return "\n".join(errors)  # No se puede continuar sin un array válido

	# Validar IDs: presencia y unicidad son errores críticos;
	# los errores de formato se registran como push_error sin bloquear la carga.
	var activities: Array = pack.get("activities", [])
	var id_errors: Array[String] = ContentIdValidatorScript.validar_ids_actividad(
		activities, pack_path
	)
	for id_error in id_errors:
		if "Missing required field" in id_error or "Duplicate content id" in id_error:
			errors.append(id_error)
		else:
			# Violación de formato: visible en el log del editor pero no bloquea la carga
			push_error(id_error)

	var catalog_result: Dictionary = _load_items_catalog()
	if not bool(catalog_result.get("ok", false)):
		errors.append(str(catalog_result.get("error", "items_celiaquia invalido.")))
		return "\n".join(errors)
	var catalog: Dictionary = catalog_result.get("data", {})
	var items_catalog: Dictionary = catalog.get("items", {})
	for raw_activity in activities:
		if not raw_activity is Dictionary:
			errors.append("cada activity debe ser objeto.")
			continue
		var activity: Dictionary = raw_activity as Dictionary
		if str(activity.get("mode", "")).strip_edges() == "drag_food":
			var drag_error: String = _validar_drag_food(activity, items_catalog)
			if not drag_error.is_empty():
				errors.append(drag_error)
	return "\n".join(errors)


static func _validar_drag_food(
	activity: Dictionary,
	items_catalog: Dictionary
) -> String:
	var activity_id: String = str(activity.get("id", "")).strip_edges()
	var meal: String = str(activity.get("meal", "")).strip_edges()
	if not VALID_MEALS.has(meal):
		return "%s usa meal invalido: %s" % [activity_id, meal]

	var pick: Dictionary = activity.get("pick", {})
	var correct_needed: int = int(pick.get("correct", 0))
	var incorrect_needed: int = int(pick.get("incorrect", -1))
	if correct_needed <= 0:
		return "%s necesita pick.correct > 0." % activity_id
	if incorrect_needed < 0:
		return "%s necesita pick.incorrect >= 0." % activity_id

	var available_correct := 0
	var available_incorrect := 0
	for raw_item_id in items_catalog.keys():
		var item: Dictionary = items_catalog.get(raw_item_id, {})
		if not _item_matches_meal(item, meal):
			continue
		if str(item.get("categoria", "")).strip_edges() == CATEGORY_SAFE:
			available_correct += 1
		else:
			available_incorrect += 1
	if available_correct < correct_needed:
		return "%s no tiene suficientes correct en meal=%s." % [activity_id, meal]
	if available_incorrect < incorrect_needed:
		return "%s no tiene suficientes incorrect en meal=%s." % [activity_id, meal]
	return ""


static func _load_items_catalog() -> Dictionary:
	if not _items_catalog_cache.is_empty():
		return {"ok": true, "error": "", "data": _items_catalog_cache}

	var file := FileAccess.open(ITEMS_CELIAQUIA_PATH, FileAccess.READ)
	if file == null:
		return _error("No se pudo abrir %s" % ITEMS_CELIAQUIA_PATH)

	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	if parse_result != OK:
		return _error(
			"Catalogo invalido en %s linea %d: %s"
			% [ITEMS_CELIAQUIA_PATH, parser.get_error_line(), parser.get_error_message()]
		)

	var parsed: Variant = parser.get_data()
	if not parsed is Dictionary:
		return _error("items_celiaquia debe ser un objeto.")
	var catalog: Dictionary = parsed as Dictionary
	var validation_error: String = _validar_items_catalog(catalog)
	if not validation_error.is_empty():
		return _error(validation_error)
	_items_catalog_cache = catalog
	return {"ok": true, "error": "", "data": _items_catalog_cache}


static func _validar_items_catalog(catalog: Dictionary) -> String:
	if str(catalog.get("base_path", "")).strip_edges().is_empty():
		return "items_celiaquia necesita base_path."
	if not catalog.get("items", {}) is Dictionary:
		return "items_celiaquia necesita items como objeto."
	var items: Dictionary = catalog.get("items", {})
	for raw_item_id in items.keys():
		var item_id: String = str(raw_item_id).strip_edges()
		if item_id.is_empty():
			return "items_celiaquia tiene item con id vacio."
		if not items.get(raw_item_id, {}) is Dictionary:
			return "%s debe ser objeto." % item_id
		var item: Dictionary = items.get(raw_item_id, {})
		var category: String = str(item.get("categoria", "")).strip_edges()
		if not VALID_CATEGORIES.has(category):
			return "%s tiene categoria invalida: %s" % [item_id, category]
		if not item.get("meal_type", []) is Array:
			return "%s necesita meal_type como array." % item_id
		var meal_types: Array = item.get("meal_type", [])
		if meal_types.is_empty():
			return "%s necesita meal_type no vacio." % item_id
		for raw_meal in meal_types:
			var meal: String = str(raw_meal).strip_edges()
			if not VALID_MEALS.has(meal):
				return "%s tiene meal_type invalido: %s" % [item_id, meal]
	return ""


static func _item_matches_meal(item: Dictionary, meal: String) -> bool:
	if not item.get("meal_type", []) is Array:
		return false
	for raw_meal in item.get("meal_type", []):
		if str(raw_meal).strip_edges() == meal:
			return true
	return false


static func _load_mapa_pack(track_id: String, mapa_dir: String) -> Dictionary:
	var activities: Array = []
	# Archivos obligatorios: si falta uno, el pack entero falla.
	for filename in ["preguntas.json", "arrastres.json", "vinculaciones.json"]:
		var result: Dictionary = _cargar_actividad_dict_file(mapa_dir + filename)
		if not bool(result.get("ok", false)):
			return result
		activities.append_array(result.get("data", []))
	# Archivos opcionales: si faltan, se ignoran con warning (no rompen las otras modalidades).
	for filename in ["completar_palabra.json"]:
		var path: String = mapa_dir + str(filename)
		if not FileAccess.file_exists(path):
			push_warning(
				"NodeContentLoader: archivo opcional no encontrado, se omite: %s" % path
			)
			continue
		var result: Dictionary = _cargar_actividad_dict_file(path)
		if not bool(result.get("ok", false)):
			push_warning(
				"NodeContentLoader: error cargando archivo opcional %s — %s"
				% [filename, str(result.get("error", ""))]
			)
			continue
		activities.append_array(result.get("data", []))
	var pack: Dictionary = {"id": track_id, "version": 1, "activities": activities}
	var validation_error: String = _validar_pack_minimal(pack, mapa_dir)
	if not validation_error.is_empty():
		return _error("Mapa %s invalido: %s" % [track_id, validation_error])
	return {"ok": true, "error": "", "data": pack, "path": mapa_dir}


static func _cargar_actividad_dict_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("No se pudo abrir: %s" % path)
	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	if parse_result != OK:
		return _error(
			"JSON invalido en %s linea %d: %s"
			% [path, parser.get_error_line(), parser.get_error_message()]
		)
	var parsed: Variant = parser.get_data()
	if not parsed is Dictionary:
		return _error("Archivo de actividades debe ser un objeto: %s" % path)
	var activities: Array = []
	for raw_key in (parsed as Dictionary).keys():
		var activity_id: String = str(raw_key).strip_edges()
		var raw_activity: Variant = (parsed as Dictionary).get(raw_key, {})
		if not raw_activity is Dictionary:
			return _error("%s: actividad '%s' debe ser objeto." % [path, activity_id])
		var activity: Dictionary = (raw_activity as Dictionary).duplicate(true)
		activity["id"] = activity_id
		activity["source_file"] = path.get_file()
		activities.append(activity)
	print(
		"%s loaded %s count=%d"
		% [LOG_PREFIX_CONTENT_MAP, path.get_file().trim_suffix(".json"), activities.size()]
	)
	return {"ok": true, "error": "", "data": activities}


static func _resolve_pack_id(pack_id: String, fallback_track_key: String = "") -> String:
	var clean_pack_id: String = pack_id.strip_edges()
	if not clean_pack_id.is_empty():
		return clean_pack_id
	var clean_track_key: String = fallback_track_key.strip_edges()
	if not clean_track_key.is_empty():
		return clean_track_key
	if not _default_pack_warning_shown:
		_default_pack_warning_shown = true
		push_warning("%s pack_id vacio; fallback=%s" % [LOG_PREFIX_CONTENT_MAP, DEFAULT_PACK_ID])
	return DEFAULT_PACK_ID


static func _guess_source_file_for_activity_id(activity_id: String) -> String:
	var clean_activity_id: String = activity_id.strip_edges().to_lower()
	if clean_activity_id.begins_with("match_"):
		return "vinculaciones.json"
	if clean_activity_id.begins_with("drag_"):
		return "arrastres.json"
	if clean_activity_id.begins_with("quiz_"):
		return "preguntas.json"
	if clean_activity_id.begins_with("word_"):
		return "opciones_palabras.json"
	return "desconocido"


## --- Delegados de transformacion runtime (fachada sobre CargadorDeContenidoDeNodo) ---

static func convertir_arrastre_a_runtime(datos_nodo: Dictionary) -> Dictionary:
	return LegacyNodeLoaderScript.convertir_arrastre_a_runtime(datos_nodo)


static func convertir_vinculacion_a_runtime(datos_nodo: Dictionary) -> Dictionary:
	return LegacyNodeLoaderScript.convertir_vinculacion_a_runtime(datos_nodo)


## ---------------------------------------------------------------------------

static func _error(message: String) -> Dictionary:
	push_error("NodeContentLoader: %s" % message)
	return {"ok": false, "error": message, "data": {}}
