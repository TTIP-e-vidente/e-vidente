extends RefCounted
class_name ActivityAdapter

const MODE_QUIZ := "quiz"
const MODE_DRAG := "drag"
const MODE_DRAG_FOOD := "drag_food"
const MODE_MATCH := "match"
const RUNTIME_QUIZ_CHOICE := "quiz_choice"
const RUNTIME_DRAG_DROP := "drag_drop"
const RUNTIME_VINCULACION := "vinculacion_conceptos"
const TARGET_ID := "target_1"
const ITEMS_CELIAQUIA_PATH := "res://contenido/catalogos/items_celiaquia.json"
const CATEGORY_SAFE := "sin_tacc"
const DRAG_FOOD_DEFAULTS := {
	"desayuno": {
		"prompt": "Prepará un desayuno apto sin TACC.",
		"target": "Desayuno apto",
	},
	"merienda": {
		"prompt": "Prepará una merienda apta sin TACC.",
		"target": "Merienda apta",
	},
	"colacion": {
		"prompt": "Prepará una colación apta sin TACC.",
		"target": "Colación apta",
	},
	"almuerzo": {
		"prompt": "Prepará un almuerzo apto sin TACC.",
		"target": "Almuerzo apto",
	},
	"cena": {
		"prompt": "Prepará una cena apta sin TACC.",
		"target": "Cena apta",
	},
	"bebida": {
		"prompt": "Elegí una bebida apta sin TACC.",
		"target": "Bebida apta",
	},
	"cocina_segura": {
		"prompt": "Elegí elementos seguros para cocinar sin TACC.",
		"target": "Cocina segura",
	},
}

static var _last_selection_by_activity: Dictionary = {}
static var _items_catalog_cache: Dictionary = {}


static func to_legacy_node(
	activity: Dictionary,
	pack_id: String = "",
	pack: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	match str(activity.get("mode", "")).strip_edges():
		MODE_QUIZ:
			return _quiz_to_legacy(activity, pack_id)
		MODE_DRAG:
			return _drag_to_legacy(activity, pack_id)
		MODE_DRAG_FOOD:
			return _drag_food_to_legacy(activity, pack_id, pack, options)
		MODE_MATCH:
			return _match_to_legacy(activity, pack_id)
		_:
			push_error("ActivityAdapter: mode no soportado: %s" % str(activity.get("mode", "")))
			return {}


static func _quiz_to_legacy(activity: Dictionary, pack_id: String) -> Dictionary:
	var answer: String = str(activity.get("answer", "")).strip_edges()
	var wrong_options: Array[String] = []
	for raw_option in activity.get("options", []):
		var option: String = str(raw_option).strip_edges()
		if option.is_empty() or option == answer:
			continue
		wrong_options.append(option)
	return _base_node(activity, pack_id, RUNTIME_QUIZ_CHOICE, {
		"question": str(activity.get("prompt", "")).strip_edges(),
		"correct_answer": answer,
		"wrong_options": wrong_options,
		"visual_resource": "",
	})


static func _drag_to_legacy(activity: Dictionary, pack_id: String) -> Dictionary:
	var target_id := "target"
	var items: Array[Dictionary] = []
	var index := 0
	for raw_item in activity.get("items", []):
		if not raw_item is Dictionary:
			continue
		var item: Dictionary = raw_item as Dictionary
		var text: String = str(item.get("text", "")).strip_edges()
		var item_id: String = _slug(text)
		if item_id.is_empty():
			item_id = "item_%d" % index
		items.append({
			"id": item_id,
			"label": text,
			"image": str(item.get("image", "")).strip_edges(),
			"correct_target": target_id if bool(item.get("correct", false)) else "",
		})
		index += 1
	return _base_node(activity, pack_id, RUNTIME_DRAG_DROP, {
		"teaching_key": "",
		"instruction": str(activity.get("prompt", "")).strip_edges(),
		"targets": [
			{
				"id": target_id,
				"label": str(activity.get("target", "")).strip_edges(),
			}
		],
		"items": items,
	})


static func _drag_food_to_legacy(
	activity: Dictionary,
	pack_id: String,
	pack: Dictionary,
	options: Dictionary
) -> Dictionary:
	var content: Dictionary = _resolve_drag_food_content(activity, pack, options)
	if content.is_empty():
		return {}
	return _base_node(activity, pack_id, RUNTIME_DRAG_DROP, content)


static func _resolve_drag_food_content(
	activity: Dictionary,
	_pack: Dictionary,
	options: Dictionary
) -> Dictionary:
	var activity_id: String = str(activity.get("id", "")).strip_edges()
	var meal: String = str(activity.get("meal", "")).strip_edges()
	var catalog_result: Dictionary = _load_items_catalog()
	if not bool(catalog_result.get("ok", false)):
		push_error("DragFood: %s" % str(catalog_result.get("error", "")))
		return {}
	var catalog: Dictionary = catalog_result.get("data", {})
	var base_path: String = str(catalog.get("base_path", "")).strip_edges()
	var items_catalog: Dictionary = catalog.get("items", {})
	var prompt: String = _drag_food_prompt(activity, meal)
	var target_label: String = _drag_food_target(activity, meal)

	var pick: Dictionary = activity.get("pick", {})
	var correct_count: int = int(pick.get("correct", 0))
	var incorrect_count: int = int(pick.get("incorrect", 0))
	var candidate_correct: Array[String] = []
	var candidate_incorrect: Array[String] = []
	for raw_item_id in items_catalog.keys():
		var item_id: String = str(raw_item_id).strip_edges()
		var item: Dictionary = items_catalog.get(raw_item_id, {})
		if not _item_matches_meal(item, meal):
			continue
		if str(item.get("categoria", "")).strip_edges() == CATEGORY_SAFE:
			candidate_correct.append(item_id)
		else:
			candidate_incorrect.append(item_id)

	if candidate_correct.size() < correct_count:
		push_error(
			"DragFood: activity=%s meal=%s correct insuficientes: pide=%d hay=%d"
			% [activity_id, meal, correct_count, candidate_correct.size()]
		)
		return {}
	if candidate_incorrect.size() < incorrect_count:
		push_error(
			"DragFood: activity=%s meal=%s incorrect insuficientes: pide=%d hay=%d"
			% [activity_id, meal, incorrect_count, candidate_incorrect.size()]
		)
		return {}

	var rng := RandomNumberGenerator.new()
	if options.has("seed"):
		rng.seed = int(options.get("seed", 0))
	else:
		rng.randomize()

	var selected_correct: Array[String] = _pick_ids(
		activity_id, candidate_correct, correct_count, rng
	)
	var selected_incorrect: Array[String] = _pick_ids(
		activity_id, candidate_incorrect, incorrect_count, rng
	)
	_last_selection_by_activity[activity_id] = selected_correct + selected_incorrect

	var items: Array[Dictionary] = []
	for food_id in selected_correct:
		items.append(_make_food_item(food_id, items_catalog.get(food_id, {}), TARGET_ID, base_path))
	for food_id in selected_incorrect:
		items.append(_make_food_item(food_id, items_catalog.get(food_id, {}), "", base_path))
	_shuffle_items(items, rng)

	print(
		"[DragFood] activity=%s meal=%s correct=%d incorrect=%d"
		% [activity_id, meal, correct_count, incorrect_count]
	)
	print(
		"[DragFood] candidates correct=%d incorrect=%d"
		% [candidate_correct.size(), candidate_incorrect.size()]
	)
	print("[DragFood] selected=%s" % _join_ids(selected_correct + selected_incorrect))
	print("[DragFood] selected_ids=%s" % _join_ids(selected_correct + selected_incorrect))

	return {
		"teaching_key": "",
		"instruction": prompt,
		"targets": [
			{
				"id": TARGET_ID,
				"label": target_label,
			}
		],
		"items": items,
	}


static func _match_to_legacy(activity: Dictionary, pack_id: String) -> Dictionary:
	var left: Array[Dictionary] = []
	var right: Array[Dictionary] = []
	var index := 0
	for raw_pair in activity.get("pairs", []):
		if not raw_pair is Array or (raw_pair as Array).size() < 2:
			continue
		var pair: Array = raw_pair as Array
		var pair_key := "pair_%d" % index
		left.append({
			"id": "%s_left" % pair_key,
			"label": str(pair[0]).strip_edges(),
			"text": str(pair[0]).strip_edges(),
			"par_key": pair_key,
		})
		right.append({
			"id": "%s_right" % pair_key,
			"label": str(pair[1]).strip_edges(),
			"text": str(pair[1]).strip_edges(),
			"par_key": pair_key,
		})
		index += 1
	return _base_node(activity, pack_id, RUNTIME_VINCULACION, {
		"instruccion": str(activity.get("prompt", "")).strip_edges(),
		"conceptos_izquierda": left,
		"conceptos_derecha": right,
		"teaching_key": "",
	})


static func _base_node(
	activity: Dictionary,
	pack_id: String,
	runtime_mode: String,
	content: Dictionary
) -> Dictionary:
	var activity_id: String = str(activity.get("id", "")).strip_edges()
	return {
		"id": activity_id,
		"theme": pack_id.strip_edges(),
		"title": activity_id,
		"difficulty": str(int(activity.get("difficulty", 1))),
		"mode": runtime_mode,
		"content": content,
	}


static func _make_food_item(
	food_id: String,
	food: Dictionary,
	correct_target: String,
	base_path: String
) -> Dictionary:
	var resource_override: String = str(food.get("resource", "")).strip_edges()
	var resource_path: String = _resolve_food_resource_path(food_id, resource_override, base_path)
	var label: String = _food_label(food_id, food)
	var feedback: String = str(food.get("feedback", "")).strip_edges()
	var item := {
		"id": food_id,
		"resource": resource_path,
		"resource_path": resource_path,
		"asset": resource_path,
		"image": resource_path,
		"label": label,
		"nombre": label,
		"correct_target": correct_target,
		"category": str(food.get("categoria", "")).strip_edges(),
		"feedback": feedback,
	}
	print(
		"[DragFoodItem] id=%s resource=%s exists=%s correct=%s label=%s"
		% [
			food_id,
			resource_path,
			str(ResourceLoader.exists(resource_path)),
			str(not correct_target.strip_edges().is_empty()),
			label,
		]
	)
	return item


static func _drag_food_prompt(activity: Dictionary, meal: String) -> String:
	var explicit_prompt: String = str(activity.get("prompt", "")).strip_edges()
	if not explicit_prompt.is_empty():
		return explicit_prompt
	return str(_drag_food_default(meal).get("prompt", "")).strip_edges()


static func _drag_food_target(activity: Dictionary, meal: String) -> String:
	var explicit_target: String = str(activity.get("target", "")).strip_edges()
	if not explicit_target.is_empty():
		return explicit_target
	return str(_drag_food_default(meal).get("target", "")).strip_edges()


static func _drag_food_default(meal: String) -> Dictionary:
	var clean_meal: String = meal.strip_edges()
	if DRAG_FOOD_DEFAULTS.has(clean_meal):
		return DRAG_FOOD_DEFAULTS.get(clean_meal, {})
	return {"prompt": "", "target": ""}


static func _resolve_food_resource_path(
	food_id: String,
	resource_override: String,
	base_path: String
) -> String:
	var direct_path: String = resource_override.strip_edges()
	if direct_path.is_empty():
		direct_path = base_path + food_id + ".tres"
	if ResourceLoader.exists(direct_path):
		return direct_path

	var resolved_by_slug: String = _find_resource_by_slug(food_id, base_path)
	if not resolved_by_slug.is_empty():
		return resolved_by_slug
	return direct_path


static func _find_resource_by_slug(food_id: String, base_path: String) -> String:
	var directory := DirAccess.open(base_path)
	if directory == null:
		return ""
	var wanted_slug: String = _slug(food_id)
	directory.list_dir_begin()
	while true:
		var filename: String = directory.get_next()
		if filename.is_empty():
			break
		if directory.current_is_dir() or not filename.ends_with(".tres"):
			continue
		if _slug(filename.get_basename()) == wanted_slug:
			directory.list_dir_end()
			return base_path + filename
	directory.list_dir_end()
	return ""


static func _food_label(food_id: String, food: Dictionary) -> String:
	var explicit_label: String = str(
		food.get("label", food.get("nombre", food.get("name", "")))
	).strip_edges()
	if not explicit_label.is_empty():
		return explicit_label
	var parts := PackedStringArray()
	for raw_part in food_id.replace("-", "_").split("_", false):
		var part: String = str(raw_part).strip_edges()
		if part.is_empty():
			continue
		parts.append(part.substr(0, 1).to_upper() + part.substr(1))
	return " ".join(parts) if parts.size() > 0 else food_id


static func _load_items_catalog() -> Dictionary:
	if not _items_catalog_cache.is_empty():
		return {"ok": true, "error": "", "data": _items_catalog_cache}
	var file := FileAccess.open(ITEMS_CELIAQUIA_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "No se pudo abrir %s" % ITEMS_CELIAQUIA_PATH, "data": {}}
	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	if parse_result != OK:
		return {
			"ok": false,
			"error": "Catalogo invalido en linea %d: %s" % [
				parser.get_error_line(),
				parser.get_error_message(),
			],
			"data": {},
		}
	var parsed: Variant = parser.get_data()
	if not parsed is Dictionary:
		return {"ok": false, "error": "El catalogo debe ser un objeto.", "data": {}}
	var catalog: Dictionary = parsed as Dictionary
	var validation_error: String = _validate_items_catalog(catalog)
	if not validation_error.is_empty():
		return {"ok": false, "error": validation_error, "data": {}}
	_items_catalog_cache = catalog
	var items: Dictionary = catalog.get("items", {})
	print("[Catalog] items_celiaquia count=%d" % items.size())
	return {"ok": true, "error": "", "data": _items_catalog_cache}


static func _validate_items_catalog(catalog: Dictionary) -> String:
	if str(catalog.get("base_path", "")).strip_edges().is_empty():
		return "items_celiaquia necesita base_path."
	if not catalog.get("items", {}) is Dictionary:
		return "items_celiaquia necesita items como objeto."
	var allowed_categories := ["sin_tacc", "con_gluten", "riesgo"]
	var allowed_meals := [
		"desayuno",
		"merienda",
		"colacion",
		"almuerzo",
		"cena",
		"bebida",
		"cocina_segura",
	]
	var items: Dictionary = catalog.get("items", {})
	for raw_item_id in items.keys():
		var item_id: String = str(raw_item_id).strip_edges()
		if item_id.is_empty():
			return "items_celiaquia tiene item con id vacio."
		if not items.get(raw_item_id, {}) is Dictionary:
			return "%s debe ser objeto." % item_id
		var item: Dictionary = items.get(raw_item_id, {})
		var category: String = str(item.get("categoria", "")).strip_edges()
		if not allowed_categories.has(category):
			return "%s tiene categoria invalida: %s" % [item_id, category]
		if not item.get("meal_type", []) is Array:
			return "%s necesita meal_type como array." % item_id
		var meal_types: Array = item.get("meal_type", [])
		if meal_types.is_empty():
			return "%s necesita meal_type no vacio." % item_id
		for raw_meal in meal_types:
			var meal: String = str(raw_meal).strip_edges()
			if not allowed_meals.has(meal):
				return "%s tiene meal_type invalido: %s" % [item_id, meal]
	return ""


static func _item_matches_meal(item: Dictionary, meal: String) -> bool:
	if not item.get("meal_type", []) is Array:
		return false
	for raw_meal in item.get("meal_type", []):
		if str(raw_meal).strip_edges() == meal:
			return true
	return false


static func _pick_ids(
	activity_id: String,
	source_ids: Array[String],
	count: int,
	rng: RandomNumberGenerator
) -> Array[String]:
	var pool: Array[String] = source_ids.duplicate()
	var last_ids: Array = _last_selection_by_activity.get(activity_id, [])
	var without_last: Array[String] = []
	for food_id in pool:
		if not last_ids.has(food_id):
			without_last.append(food_id)
	if without_last.size() >= count:
		pool = without_last

	var selected: Array[String] = []
	while not pool.is_empty() and selected.size() < count:
		var index: int = rng.randi_range(0, pool.size() - 1)
		selected.append(pool[index])
		pool.remove_at(index)
	return selected


static func _shuffle_items(items: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temp: Dictionary = items[index]
		items[index] = items[swap_index]
		items[swap_index] = temp


static func _read_id_list(raw_value: Variant) -> Array[String]:
	var ids: Array[String] = []
	if not raw_value is Array:
		return ids
	for raw_id in raw_value as Array:
		var food_id: String = str(raw_id).strip_edges()
		if not food_id.is_empty() and not ids.has(food_id):
			ids.append(food_id)
	return ids


static func _join_ids(ids: Array[String]) -> String:
	var parts := PackedStringArray()
	for food_id in ids:
		parts.append(food_id)
	return ",".join(parts)


static func _slug(text: String) -> String:
	var clean := text.strip_edges().to_lower()
	var result := ""
	for index in range(clean.length()):
		var character_code: int = clean.unicode_at(index)
		var character := clean.substr(index, 1)
		var is_ascii_letter: bool = (
			(character_code >= 97 and character_code <= 122)
			or (character_code >= 48 and character_code <= 57)
		)
		if is_ascii_letter:
			result += character
		elif character == " " or character == "-":
			result += "_"
	return result.strip_edges().trim_prefix("_").trim_suffix("_")
