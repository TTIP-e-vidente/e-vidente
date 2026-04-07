extends Node

var almuerzo_cena = "ALMCENA"
var desayuno_merienda = "DESAMER"
var bebida = "BEBIDA"

const DESAYUNO_PATH := "res://assets-sistema/interfaz/desayuno.png"
const ALMUERZO_PATH := "res://assets-sistema/interfaz/almuerzo.png"
const MERIENDA_PATH := "res://assets-sistema/interfaz/merienda.png"
const CENA_PATH := "res://assets-sistema/interfaz/cena.png"
const BEBIDA_PATH := "res://assets-sistema/interfaz/cena.png"

const PREPARA_CELIAQUIA_PATH := "res://assets-sistema/interfaz/prepara-celiaquia.png"
const PREPARA_DIABETES_PATH := "res://assets-sistema/interfaz/prepara-diabetes.png"
const PREPARA_VEGANE_PATH := "res://assets-sistema/interfaz/prepara-vegane.png"
const PREPARA_VEGETARIANE_PATH := "res://assets-sistema/interfaz/prepara-vegetariane.png"
const PREPARA_VEGAN_GF_PATH := "res://assets-sistema/interfaz/prepara-vegan-gf.png"
const PREPARA_KETO_PATH := "res://assets-sistema/interfaz/prepara-keto.png"

const ENSENANZA_CELIAQUIA_1_PATH := "res://assets-sistema/ensenanza/ensenanza-celiaquia-1.png"
const ENSENANZA_CELIAQUIA_2_PATH := "res://assets-sistema/ensenanza/ensenanza-celiaquia-2.png"
const ENSENANZA_CELIAQUIA_3_PATH := "res://assets-sistema/ensenanza/ensenanza-celiaquia-3.png"
const ENSENANZA_CELIAQUIA_4_PATH := "res://assets-sistema/ensenanza/ensenanza-celiaquia-4.png"
const ENSENANZA_CELIAQUIA_5_PATH := "res://assets-sistema/ensenanza/ensenanza-celiaquia-5.png"
const ENSENANZA_CELIAQUIA_6_PATH := "res://assets-sistema/ensenanza/ensenanza-celiaquia-6.png"
const ENSENANZA_CELIAQUIA_7_PATH := "res://assets-sistema/ensenanza/ensenanza-celiaquia-7.png"
const ENSENANZA_CELIAQUIA_8_PATH := "res://assets-sistema/ensenanza/ensenanza-celiaquia-8.png"
const ENSENANZA_CELIAQUIA_9_PATH := "res://assets-sistema/ensenanza/ensenanza-celiaquia-9.png"

const ENSENANZA_VEGAN_VEGETARIANE_1_PATH := "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-1.png"
const ENSENANZA_VEGAN_VEGETARIANE_2_PATH := "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-2.png"
const ENSENANZA_VEGAN_VEGETARIANE_3_PATH := "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-3.png"
const ENSENANZA_VEGAN_VEGETARIANE_4_PATH := "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-4.png"
const ENSENANZA_VEGAN_VEGETARIANE_5_PATH := "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-5.png"
const ENSENANZA_VEGAN_VEGETARIANE_6_PATH := "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-6.png"
const ENSENANZA_VEGAN_VEGETARIANE_7_PATH := "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-7.png"
const ENSENANZA_VEGAN_VEGETARIANE_8_PATH := "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-8.png"

var _texture_cache: Dictionary = {}

var playerCambiante
var is_dragging : Object
var manager_level 
var current_level: int = 1
const LEVEL_STATUS_INDEX := 6
const LEVELS_PER_BOOK := 6
const TRACK_KEYS := ["celiaquia", "veganismo", "veganismo_celiaquia", "cetogenica"]
const PARTIAL_LEVEL_STATES_KEY := "partial_level_states"
const PARTIAL_LEVEL_ITEMS_KEY := "items"
const PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY := "placed_item_ids"

var partial_level_states: Dictionary = _default_partial_level_states()

func items_segun_nivel(nivel) -> Dictionary:
	if nivel != null and nivel.has_method("_get_resume_track_key"):
		var track_key := str(nivel._get_resume_track_key()).strip_edges()
		var items_by_track := items_segun_track(track_key)
		if not items_by_track.is_empty():
			return items_by_track

	if nivel == null:
		return items_level_vegan_gf

	if nivel.name == "Level":
		return items_level
	elif nivel.name == "Level-Keto":
		return items_level_keto
	elif nivel.name == "Level-Vegan":
		return items_level_vegan
	else:
		return items_level_vegan_gf


func items_segun_track(track_key: String) -> Dictionary:
	return _book_for_track(track_key)

func item_categoria(items, cate):
	var items_categoria = []
	for i in items : 
		if i.categoria == cate:
			items_categoria.append(i)
	return items_categoria

var items_level = {	
					1: _level_entry(1, 1, ALMUERZO_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_1_PATH, almuerzo_cena), 
					2: _level_entry(2, 3, DESAYUNO_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_2_PATH, desayuno_merienda),
					3: _level_entry(2, 3, CENA_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_6_PATH, almuerzo_cena),
					4: _level_entry(3, 3, DESAYUNO_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_8_PATH, desayuno_merienda),
					5: _level_entry(4, 2, ALMUERZO_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_5_PATH, almuerzo_cena),
					6: _level_entry(1, 3, BEBIDA_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_7_PATH, bebida)
					}

var items_level_vegan = {	
					1: _level_entry(1, 2, ALMUERZO_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_1_PATH, almuerzo_cena), 
					2: _level_entry(2, 2, DESAYUNO_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_2_PATH, desayuno_merienda),
					3: _level_entry(2, 3, CENA_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_3_PATH, almuerzo_cena),
					4: _level_entry(2, 4, DESAYUNO_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_4_PATH, desayuno_merienda),
					5: _level_entry(4, 2, ALMUERZO_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_5_PATH, almuerzo_cena),
					6: _level_entry(1, 3, BEBIDA_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_6_PATH, bebida)
					}

var items_level_vegan_gf = {	
					1: _level_entry(1, 1, ALMUERZO_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_CELIAQUIA_3_PATH, almuerzo_cena), 
					2: _level_entry(1, 2, DESAYUNO_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_VEGAN_VEGETARIANE_7_PATH, desayuno_merienda),
					3: _level_entry(2, 4, CENA_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_CELIAQUIA_4_PATH, almuerzo_cena),
					4: _level_entry(4, 2, DESAYUNO_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_VEGAN_VEGETARIANE_8_PATH, desayuno_merienda),
					5: _level_entry(4, 2, ALMUERZO_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_CELIAQUIA_9_PATH, almuerzo_cena),
					6: _level_entry(2, 2, BEBIDA_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_CELIAQUIA_7_PATH, bebida)
					}

var items_level_keto = {	
					1: _level_entry(1, 1, ALMUERZO_PATH, PREPARA_KETO_PATH, ENSENANZA_CELIAQUIA_3_PATH, almuerzo_cena), 
					2: _level_entry(1, 2, DESAYUNO_PATH, PREPARA_KETO_PATH, ENSENANZA_VEGAN_VEGETARIANE_7_PATH, desayuno_merienda),
					3: _level_entry(2, 4, CENA_PATH, PREPARA_KETO_PATH, ENSENANZA_CELIAQUIA_4_PATH, almuerzo_cena),
					4: _level_entry(4, 2, DESAYUNO_PATH, PREPARA_KETO_PATH, ENSENANZA_VEGAN_VEGETARIANE_8_PATH, desayuno_merienda),
					5: _level_entry(4, 2, ALMUERZO_PATH, PREPARA_KETO_PATH, ENSENANZA_CELIAQUIA_9_PATH, almuerzo_cena),
					6: _level_entry(2, 2, BEBIDA_PATH, PREPARA_KETO_PATH, ENSENANZA_CELIAQUIA_7_PATH, bebida)
					}

func _level_entry(cantidad_negativos: int, cantidad_positivos: int, comida_path: String, condicion_path: String, ensenanza_path: String, categoria: String) -> Array:
	return [cantidad_negativos, cantidad_positivos, comida_path, condicion_path, ensenanza_path, categoria, false]


func resolve_texture(texture_ref: Variant) -> Texture2D:
	if texture_ref is Texture2D:
		return texture_ref

	var texture_path := str(texture_ref)
	if texture_path.is_empty():
		return null

	if _texture_cache.has(texture_path):
		return _texture_cache[texture_path]

	var texture := load(texture_path) as Texture2D
	_texture_cache[texture_path] = texture
	return texture


func reset_progress() -> void:
	_reset_book_progress(items_level)
	_reset_book_progress(items_level_vegan)
	_reset_book_progress(items_level_vegan_gf)
	_reset_book_progress(items_level_keto)
	current_level = 1
	partial_level_states = _default_partial_level_states()


func export_progress() -> Dictionary:
	return {
		"current_level": current_level,
		"celiaquia": _export_book_progress(items_level),
		"veganismo": _export_book_progress(items_level_vegan),
		"veganismo_celiaquia": _export_book_progress(items_level_vegan_gf),
		"cetogenica": _export_book_progress(items_level_keto),

		PARTIAL_LEVEL_STATES_KEY: _export_partial_level_states()
	}


func import_progress(progress: Dictionary) -> void:
	reset_progress()
	if progress.is_empty():
		return

	current_level = clampi(int(progress.get("current_level", 1)), 1, LEVELS_PER_BOOK)
	_import_book_progress(items_level, progress.get("celiaquia", []))
	_import_book_progress(items_level_vegan, progress.get("veganismo", []))
	_import_book_progress(items_level_vegan_gf, progress.get("veganismo_celiaquia", []))
	_import_book_progress(items_level_keto, progress.get("cetogenica", []))
	partial_level_states = _normalize_partial_level_states(progress.get(PARTIAL_LEVEL_STATES_KEY, {}))
	_prune_partial_level_states()


func get_progress_summary() -> Dictionary:
	var celiaquia_completed := _count_completed_levels(items_level)
	var vegan_completed := _count_completed_levels(items_level_vegan)
	var vegan_gf_completed := _count_completed_levels(items_level_vegan_gf)
	var keto_completed := _count_completed_levels(items_level_keto)
	return {
		"celiaquia": celiaquia_completed,
		"veganismo": vegan_completed,
		"veganismo_celiaquia": vegan_gf_completed,
		"cetogenica": keto_completed,
		"total": celiaquia_completed + vegan_completed + vegan_gf_completed + keto_completed,
		"max_total": LEVELS_PER_BOOK * TRACK_KEYS.size()
	}


func get_partial_level_state(track_key: String, level_number: int) -> Dictionary:
	var clean_track_key := track_key.strip_edges()
	if not TRACK_KEYS.has(clean_track_key):
		return {}
	var track_states = partial_level_states.get(clean_track_key, {})
	if not track_states is Dictionary:
		return {}
	var clean_level_number := clampi(level_number, 1, LEVELS_PER_BOOK)
	return _normalize_partial_level_state(track_states.get(str(clean_level_number), {}))


func set_partial_level_state(track_key: String, level_number: int, state: Dictionary) -> void:
	var clean_track_key := track_key.strip_edges()
	if not TRACK_KEYS.has(clean_track_key):
		return
	var clean_level_number := clampi(level_number, 1, LEVELS_PER_BOOK)
	var track_states = partial_level_states.get(clean_track_key, {})
	if not track_states is Dictionary:
		track_states = {}
	if _is_level_completed(clean_track_key, clean_level_number):
		track_states.erase(str(clean_level_number))
		partial_level_states[clean_track_key] = track_states
		return
	var normalized_state := _normalize_partial_level_state(state)
	if normalized_state.is_empty():
		track_states.erase(str(clean_level_number))
	else:
		track_states[str(clean_level_number)] = normalized_state
	partial_level_states[clean_track_key] = track_states


func clear_partial_level_state(track_key: String, level_number: int) -> void:
	var clean_track_key := track_key.strip_edges()
	if not TRACK_KEYS.has(clean_track_key):
		return
	var clean_level_number := clampi(level_number, 1, LEVELS_PER_BOOK)
	var track_states = partial_level_states.get(clean_track_key, {})
	if not track_states is Dictionary:
		track_states = {}
	track_states.erase(str(clean_level_number))
	partial_level_states[clean_track_key] = track_states


func _reset_book_progress(book: Dictionary) -> void:
	for level_number in range(1, LEVELS_PER_BOOK + 1):
		if book.has(level_number):
			book[level_number][LEVEL_STATUS_INDEX] = false


func _export_book_progress(book: Dictionary) -> Array:
	var progress: Array = []
	for level_number in range(1, LEVELS_PER_BOOK + 1):
		progress.append(book.has(level_number) and bool(book[level_number][LEVEL_STATUS_INDEX]))
	return progress


func _import_book_progress(book: Dictionary, stored_progress: Variant) -> void:
	if stored_progress is Array:
		for level_index in range(min(stored_progress.size(), LEVELS_PER_BOOK)):
			var level_number := level_index + 1
			if book.has(level_number):
				book[level_number][LEVEL_STATUS_INDEX] = bool(stored_progress[level_index])


func _count_completed_levels(book: Dictionary) -> int:
	var completed := 0
	for level_number in range(1, LEVELS_PER_BOOK + 1):
		if book.has(level_number) and bool(book[level_number][LEVEL_STATUS_INDEX]):
			completed += 1
	return completed


func _default_partial_level_states() -> Dictionary:
	return {
		"celiaquia": {},
		"veganismo": {},
		"veganismo_celiaquia": {},
		"cetogenica": {}
	}


func _export_partial_level_states() -> Dictionary:
	var exported_states := {}
	for track_key in TRACK_KEYS:
		var raw_track_states = partial_level_states.get(track_key, {})
		if not raw_track_states is Dictionary:
			continue
		var normalized_track_states := {}
		for raw_level_key in raw_track_states.keys():
			var clean_level_key := str(raw_level_key).strip_edges()
			var normalized_state := _normalize_partial_level_state(raw_track_states[raw_level_key])
			if clean_level_key.is_empty() or normalized_state.is_empty():
				continue
			normalized_track_states[clean_level_key] = normalized_state
		if not normalized_track_states.is_empty():
			exported_states[track_key] = normalized_track_states
	return exported_states


func _normalize_partial_level_states(raw_states: Variant) -> Dictionary:
	var normalized_states := _default_partial_level_states()
	if not raw_states is Dictionary:
		return normalized_states
	for track_key in TRACK_KEYS:
		var raw_track_states = raw_states.get(track_key, {})
		if not raw_track_states is Dictionary:
			continue
		var normalized_track_states := {}
		for raw_level_key in raw_track_states.keys():
			var clean_level_key := str(raw_level_key).strip_edges()
			if not clean_level_key.is_valid_int():
				continue
			var clean_level_number := clampi(int(clean_level_key), 1, LEVELS_PER_BOOK)
			var normalized_state := _normalize_partial_level_state(raw_track_states[raw_level_key])
			if normalized_state.is_empty():
				continue
			normalized_track_states[str(clean_level_number)] = normalized_state
		normalized_states[track_key] = normalized_track_states
	return normalized_states


func _normalize_partial_level_state(raw_state: Variant) -> Dictionary:
	if not raw_state is Dictionary:
		return {}
	var raw_items = raw_state.get(PARTIAL_LEVEL_ITEMS_KEY, [])
	var raw_placed_item_ids = raw_state.get(PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY, [])
	var normalized_items: Array = []
	var positive_item_ids := {}
	if raw_items is Array:
		for raw_item in raw_items:
			if not raw_item is Dictionary:
				continue
			var item_path := str(raw_item.get("item_path", "")).strip_edges()
			var instance_id := str(raw_item.get("instance_id", "")).strip_edges()
			if item_path.is_empty() or instance_id.is_empty():
				continue
			var normalized_item := {
				"item_path": item_path,
				"instance_id": instance_id,
				"is_positive": bool(raw_item.get("is_positive", false))
			}
			normalized_items.append(normalized_item)
			if bool(normalized_item.get("is_positive", false)):
				positive_item_ids[instance_id] = true
	if normalized_items.is_empty():
		return {}
	var normalized_placed_item_ids: Array = []
	if raw_placed_item_ids is Array:
		for raw_item_id in raw_placed_item_ids:
			var clean_item_id := str(raw_item_id).strip_edges()
			if clean_item_id.is_empty() or normalized_placed_item_ids.has(clean_item_id):
				continue
			if positive_item_ids.has(clean_item_id):
				normalized_placed_item_ids.append(clean_item_id)
	return {
		PARTIAL_LEVEL_ITEMS_KEY: normalized_items,
		PARTIAL_LEVEL_PLACED_ITEM_IDS_KEY: normalized_placed_item_ids
	}


func _prune_partial_level_states() -> void:
	for track_key in TRACK_KEYS:
		var track_states = partial_level_states.get(track_key, {})
		if not track_states is Dictionary:
			partial_level_states[track_key] = {}
			continue
		for raw_level_key in track_states.keys():
			var clean_level_key := str(raw_level_key).strip_edges()
			if not clean_level_key.is_valid_int():
				track_states.erase(raw_level_key)
				continue
			var level_number := clampi(int(clean_level_key), 1, LEVELS_PER_BOOK)
			if _is_level_completed(track_key, level_number):
				track_states.erase(raw_level_key)
		partial_level_states[track_key] = track_states


func _book_for_track(track_key: String) -> Dictionary:
	match track_key:
		"celiaquia":
			return items_level
		"veganismo":
			return items_level_vegan
		"veganismo_celiaquia":
			return items_level_vegan_gf
		"cetogenica":
			return items_level_keto
		_:
			return {}


func _is_level_completed(track_key: String, level_number: int) -> bool:
	var book := _book_for_track(track_key)
	if not book.has(level_number):
		return false
	return bool(book[level_number][LEVEL_STATUS_INDEX])
