extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

const DESAYUNO_PATH := "res://assets-sistema/interfaz/desayuno.png"
const ALMUERZO_PATH := "res://assets-sistema/interfaz/almuerzo.png"
const CENA_PATH := "res://assets-sistema/interfaz/cena.png"
const BEBIDA_PATH := "res://assets-sistema/interfaz/cena.png"

const PREPARA_CELIAQUIA_PATH := "res://assets-sistema/interfaz/prepara-celiaquia.png"
const PREPARA_VEGANE_PATH := "res://assets-sistema/interfaz/prepara-vegane.png"
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

var TRACK_CHAPTER_DEFINITIONS: Dictionary = {
	"celiaquia": {
		1: {"runs": [
			_run_entry(1, 1, ALMUERZO_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_1_PATH, GameTrackCatalog.CATEGORY_ALMUERZO_CENA),
			_run_entry(1, 1, DESAYUNO_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_2_PATH, GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)
		]},
		2: {"runs": [
			_run_entry(2, 3, DESAYUNO_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_2_PATH, GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA),
			_run_entry(1, 2, BEBIDA_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_7_PATH, GameTrackCatalog.CATEGORY_BEBIDA)
		]},
		3: {"runs": [_run_entry(2, 3, CENA_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_6_PATH, GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		4: {"runs": [_run_entry(3, 3, DESAYUNO_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_8_PATH, GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)]},
		5: {"runs": [_run_entry(4, 2, ALMUERZO_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_5_PATH, GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		6: {"runs": [_run_entry(1, 3, BEBIDA_PATH, PREPARA_CELIAQUIA_PATH, ENSENANZA_CELIAQUIA_7_PATH, GameTrackCatalog.CATEGORY_BEBIDA)]}
	},
	"veganismo": {
		1: {"runs": [
			_run_entry(1, 2, ALMUERZO_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_1_PATH, GameTrackCatalog.CATEGORY_ALMUERZO_CENA),
			_run_entry(1, 1, DESAYUNO_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_2_PATH, GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)
		]},
		2: {"runs": [
			_run_entry(2, 2, DESAYUNO_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_2_PATH, GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA),
			_run_entry(1, 2, BEBIDA_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_6_PATH, GameTrackCatalog.CATEGORY_BEBIDA)
		]},
		3: {"runs": [_run_entry(2, 3, CENA_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_3_PATH, GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		4: {"runs": [_run_entry(2, 4, DESAYUNO_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_4_PATH, GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)]},
		5: {"runs": [_run_entry(4, 2, ALMUERZO_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_5_PATH, GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		6: {"runs": [_run_entry(1, 3, BEBIDA_PATH, PREPARA_VEGANE_PATH, ENSENANZA_VEGAN_VEGETARIANE_6_PATH, GameTrackCatalog.CATEGORY_BEBIDA)]}
	},
	"veganismo_celiaquia": {
		1: {"runs": [
			_run_entry(1, 1, ALMUERZO_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_CELIAQUIA_3_PATH, GameTrackCatalog.CATEGORY_ALMUERZO_CENA),
			_run_entry(1, 1, DESAYUNO_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_VEGAN_VEGETARIANE_7_PATH, GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)
		]},
		2: {"runs": [
			_run_entry(1, 2, DESAYUNO_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_VEGAN_VEGETARIANE_7_PATH, GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA),
			_run_entry(1, 1, BEBIDA_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_CELIAQUIA_7_PATH, GameTrackCatalog.CATEGORY_BEBIDA)
		]},
		3: {"runs": [_run_entry(2, 4, CENA_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_CELIAQUIA_4_PATH, GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		4: {"runs": [_run_entry(4, 2, DESAYUNO_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_VEGAN_VEGETARIANE_8_PATH, GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)]},
		5: {"runs": [_run_entry(4, 2, ALMUERZO_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_CELIAQUIA_9_PATH, GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		6: {"runs": [_run_entry(2, 2, BEBIDA_PATH, PREPARA_VEGAN_GF_PATH, ENSENANZA_CELIAQUIA_7_PATH, GameTrackCatalog.CATEGORY_BEBIDA)]}
	}
}

var _track_books: Dictionary = _build_track_books()
var items_level: Dictionary = _track_books.get("celiaquia", {})
var items_level_vegan: Dictionary = _track_books.get("veganismo", {})
var items_level_vegan_gf: Dictionary = _track_books.get("veganismo_celiaquia", {})

func item_categoria(items, categoria: String) -> Array:
	if categoria.strip_edges().is_empty():
		return items.duplicate()
	var items_categoria: Array = []
	var normalized_category: String = GameTrackCatalog.normalize_category_code(categoria)
	for item in items:
		if GameTrackCatalog.categories_match(str(item.categoria), normalized_category):
			items_categoria.append(item)
	return items_categoria


func get_track_level_count(track_key: String, fallback: int = 0) -> int:
	var chapters: Variant = TRACK_CHAPTER_DEFINITIONS.get(track_key, {})
	return chapters.size() if chapters is Dictionary and chapters.size() > 0 else fallback


func get_max_track_level_count(fallback: int = 0) -> int:
	var max_level_count := fallback
	for track_key in GameTrackCatalog.get_track_keys():
		max_level_count = max(max_level_count, get_track_level_count(track_key, fallback))
	return max_level_count


func get_total_level_count(fallback: int = 0) -> int:
	var total_levels := 0
	for track_key in GameTrackCatalog.get_track_keys():
		total_levels += get_track_level_count(track_key, fallback)
	return total_levels


func get_chapter_definition(track_key: String, level_number: int) -> Dictionary:
	var chapters: Variant = TRACK_CHAPTER_DEFINITIONS.get(track_key, {})
	if not chapters is Dictionary or not chapters.has(level_number) or not chapters[level_number] is Dictionary:
		return {}
	return (chapters[level_number] as Dictionary).duplicate(true)


func get_chapter_run_count(track_key: String, level_number: int) -> int:
	var runs: Variant = get_chapter_definition(track_key, level_number).get("runs", [])
	return runs.size() if runs is Array else 0


func get_chapter_run(track_key: String, level_number: int, run_index: int = 1) -> Dictionary:
	var chapter_definition: Dictionary = get_chapter_definition(track_key, level_number)
	var runs: Variant = chapter_definition.get("runs", [])
	if not runs is Array or runs.is_empty():
		return {}
	return (runs[clampi(run_index, 1, runs.size()) - 1] as Dictionary).duplicate(true)

func resolve_texture(texture_ref: Variant) -> Texture2D:
	if texture_ref is Texture2D:
		return texture_ref
	var texture_path: String = str(texture_ref)
	if texture_path.is_empty():
		return null
	if _texture_cache.has(texture_path):
		return _texture_cache[texture_path]
	var texture: Texture2D = load(texture_path) as Texture2D
	_texture_cache[texture_path] = texture
	return texture

func get_track_books() -> Dictionary:
	return _track_books

func book_for_track(track_key: String) -> Dictionary:
	var book: Variant = _track_books.get(track_key, {})
	return book if book is Dictionary else {}


func _build_track_books() -> Dictionary:
	var books: Dictionary = {}
	for track_key in GameTrackCatalog.get_track_keys():
		books[track_key] = _build_track_book(track_key)
	return books


func _build_track_book(track_key: String) -> Dictionary:
	var book: Dictionary = {}
	var chapters: Variant = TRACK_CHAPTER_DEFINITIONS.get(track_key, {})
	if not chapters is Dictionary:
		return book
	var level_numbers: Array[int] = []
	for raw_level_number in chapters.keys():
		level_numbers.append(int(raw_level_number))
	level_numbers.sort()
	for level_number in level_numbers:
		var first_run: Dictionary = get_chapter_run(track_key, level_number, 1)
		book[level_number] = [int(first_run.get("negative_count", 0)), int(first_run.get("positive_count", 0)), str(first_run.get("meal_texture_path", "")), str(first_run.get("condition_texture_path", "")), str(first_run.get("teaching_texture_path", "")), str(first_run.get("category", "")), false]
	return book


func _run_entry(negative_count: int, positive_count: int, meal_texture_path: String, condition_texture_path: String, teaching_texture_path: String, category: String) -> Dictionary:
	var mechanic_payload: Dictionary = {
		"negative_count": negative_count,
		"positive_count": positive_count,
		"category": category
	}
	return {
		"mechanic_type": LevelMechanicTypes.PLATE_SORT,
		"mechanic_payload": mechanic_payload,
		"negative_count": negative_count,
		"positive_count": positive_count,
		"meal_texture_path": meal_texture_path,
		"condition_texture_path": condition_texture_path,
		"teaching_texture_path": teaching_texture_path,
		"category": category
	}
