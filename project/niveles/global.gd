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

func items_segun_nivel(nivel):
	if nivel.name == "Level": 
		return items_level 
	elif nivel.name == "Level-Vegan": 
		return items_level_vegan
	else:
		return items_level_vegan_gf

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
	current_level = 1


func export_progress() -> Dictionary:
	return {
		"current_level": current_level,
		"celiaquia": _export_book_progress(items_level),
		"veganismo": _export_book_progress(items_level_vegan),
		"veganismo_celiaquia": _export_book_progress(items_level_vegan_gf)
	}


func import_progress(progress: Dictionary) -> void:
	reset_progress()
	if progress.is_empty():
		return

	current_level = clampi(int(progress.get("current_level", 1)), 1, LEVELS_PER_BOOK)
	_import_book_progress(items_level, progress.get("celiaquia", []))
	_import_book_progress(items_level_vegan, progress.get("veganismo", []))
	_import_book_progress(items_level_vegan_gf, progress.get("veganismo_celiaquia", []))


func get_progress_summary() -> Dictionary:
	var celiaquia_completed := _count_completed_levels(items_level)
	var vegan_completed := _count_completed_levels(items_level_vegan)
	var vegan_gf_completed := _count_completed_levels(items_level_vegan_gf)
	return {
		"celiaquia": celiaquia_completed,
		"veganismo": vegan_completed,
		"veganismo_celiaquia": vegan_gf_completed,
		"total": celiaquia_completed + vegan_completed + vegan_gf_completed,
		"max_total": LEVELS_PER_BOOK * 3
	}


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
