extends RefCounted
class_name NodeContentLoader

const ActivityAdapterScript := preload("res://sistemas/contenido/ActivityAdapter.gd")
const LegacyNodeLoaderScript := preload("res://sistemas/contenido/CargadorDeContenidoDeNodo.gd")

const PACK_PATH_BY_ID := {
	"celiaquia": "res://contenido/packs/celiaquia_pack.json",
}
const MAPA_DIR_BY_TRACK := {
	"celiaquia": "res://contenido/mapa/",
}
const ITEMS_CELIAQUIA_PATH := "res://contenido/catalogos/items_celiaquia.json"
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


static func load_activity_from_node(node_data: Dictionary) -> Dictionary:
	return load_from_context(node_data)

static func load_from_context(context: Dictionary) -> Dictionary:
	var node_key: String = str(
		context.get("node_key", context.get("clave_nodo_de_origen", ""))
	).strip_edges()
	var activity_id: String = str(context.get("activity_id", "")).strip_edges()
	if not activity_id.is_empty():
		var pack_id: String = str(context.get("pack_id", context.get("track_key", ""))).strip_edges()
		if pack_id.is_empty():
			pack_id = "celiaquia"
		var pack_result: Dictionary = load_from_pack(pack_id, activity_id, context)
		if bool(pack_result.get("ok", false)):
			print(
				"[ContentPack] node=%s activity=%s mode=%s"
				% [
					node_key,
					activity_id,
					str(pack_result.get("activity_mode", "")).strip_edges(),
				]
			)
		elif not str(context.get("json_path", "")).strip_edges().is_empty():
			push_warning(
				"[ContentPack] node=%s activity=%s error=%s. Se usa LegacyJSON fallback."
				% [node_key, activity_id, str(pack_result.get("error", ""))]
			)
			var fallback_path: String = str(context.get("json_path", "")).strip_edges()
			print("[LegacyJSON] fallback usado path=%s" % fallback_path)
			return LegacyNodeLoaderScript.cargar_contenido_nodo(fallback_path)
		return pack_result

	var json_path: String = str(context.get("json_path", "")).strip_edges()
	if json_path.is_empty():
		return _error("El nodo no tiene activity_id ni json_path.")
	print("[LegacyJSON] node=%s path=%s" % [node_key, json_path])
	return LegacyNodeLoaderScript.cargar_contenido_nodo(json_path)


static func load_from_pack(
	pack_id: String,
	activity_id: String,
	options: Dictionary = {}
) -> Dictionary:
	var activity_result: Dictionary = load_activity(pack_id, activity_id)
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
	var adapted: Dictionary = ActivityAdapterScript.to_legacy_node(
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
	var clean_pack_id: String = pack_id.strip_edges()
	var mapa_dir: String = str(MAPA_DIR_BY_TRACK.get(clean_pack_id, "")).strip_edges()
	if not mapa_dir.is_empty():
		return _load_mapa_pack(clean_pack_id, mapa_dir)

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
	var validation_error: String = _validate_pack_minimal(pack)
	if not validation_error.is_empty():
		return _error("Content Pack %s invalido: %s" % [clean_pack_id, validation_error])

	print(
		"[ContentPack] pack cargado id=%s version=%d"
		% [clean_pack_id, int(pack.get("version", 0))]
	)
	return {"ok": true, "error": "", "data": pack, "path": pack_path}


static func load_activity(pack_id: String, activity_id: String) -> Dictionary:
	var pack_result: Dictionary = load_pack(pack_id)
	if not bool(pack_result.get("ok", false)):
		return pack_result

	var pack: Dictionary = pack_result.get("data", {})
	var activity: Dictionary = get_activity(pack, activity_id)
	if activity.is_empty():
		return _error(
			"Content Pack %s no contiene activity_id: %s"
			% [pack_id.strip_edges(), activity_id.strip_edges()]
		)

	return {
		"ok": true,
		"error": "",
		"data": activity,
		"pack": pack,
		"path": str(pack_result.get("path", "")),
	}


static func has_activity(pack_id: String, activity_id: String) -> Dictionary:
	var result: Dictionary = load_activity(pack_id, activity_id)
	if bool(result.get("ok", false)):
		return {"ok": true, "error": ""}
	return {"ok": false, "error": str(result.get("error", ""))}


static func get_activity_mode(pack_id: String, activity_id: String) -> String:
	var result: Dictionary = load_activity(pack_id, activity_id)
	if not bool(result.get("ok", false)):
		return ""
	var activity: Dictionary = result.get("data", {})
	match str(activity.get("mode", "")).strip_edges():
		"quiz":
			return "quiz_choice"
		"drag", "drag_food":
			return "drag_drop"
		"match":
			return "vinculacion_conceptos"
	return ""


static func get_activity(pack: Dictionary, activity_id: String) -> Dictionary:
	var clean_activity_id: String = activity_id.strip_edges()
	for raw_activity in pack.get("activities", []):
		if raw_activity is Dictionary:
			var activity: Dictionary = raw_activity as Dictionary
			if str(activity.get("id", "")).strip_edges() == clean_activity_id:
				return activity.duplicate(true)
	return {}


static func _validate_pack_minimal(pack: Dictionary) -> String:
	if str(pack.get("id", "")).strip_edges().is_empty():
		return "falta id."
	if int(pack.get("version", 0)) <= 0:
		return "falta version valida."
	if not pack.get("activities", []) is Array:
		return "activities debe ser array."

	var catalog_result: Dictionary = _load_items_catalog()
	if not bool(catalog_result.get("ok", false)):
		return str(catalog_result.get("error", "items_celiaquia invalido."))
	var catalog: Dictionary = catalog_result.get("data", {})
	var items_catalog: Dictionary = catalog.get("items", {})
	for raw_activity in pack.get("activities", []):
		if not raw_activity is Dictionary:
			return "cada activity debe ser objeto."
		var activity: Dictionary = raw_activity as Dictionary
		var activity_id: String = str(activity.get("id", "")).strip_edges()
		if activity_id.is_empty():
			return "activity sin id."
		if str(activity.get("mode", "")).strip_edges() == "drag_food":
			var error: String = _validate_drag_food(activity, items_catalog)
			if not error.is_empty():
				return error
	return ""


static func _validate_drag_food(
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
	var validation_error: String = _validate_items_catalog(catalog)
	if not validation_error.is_empty():
		return _error(validation_error)
	return {"ok": true, "error": "", "data": catalog}


static func _validate_items_catalog(catalog: Dictionary) -> String:
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
	for filename in ["preguntas.json", "arrastres.json", "vinculaciones.json"]:
		var result: Dictionary = _load_activity_dict_file(mapa_dir + filename)
		if not bool(result.get("ok", false)):
			return result
		activities.append_array(result.get("data", []))
	var pack: Dictionary = {"id": track_id, "version": 1, "activities": activities}
	var validation_error: String = _validate_pack_minimal(pack)
	if not validation_error.is_empty():
		return _error("Mapa %s invalido: %s" % [track_id, validation_error])
	print("[ContentPack] mapa cargado id=%s activities=%d" % [track_id, activities.size()])
	return {"ok": true, "error": "", "data": pack, "path": mapa_dir}


static func _load_activity_dict_file(path: String) -> Dictionary:
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
		activities.append(activity)
	return {"ok": true, "error": "", "data": activities}


static func _error(message: String) -> Dictionary:
	push_error("NodeContentLoader: %s" % message)
	return {"ok": false, "error": message, "data": {}}
