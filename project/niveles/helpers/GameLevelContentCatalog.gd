extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameTrackChapterCatalogScript := preload(
	"res://niveles/helpers/catalog/GameTrackChapterDefinitions.gd"
)
const GameContentCatalogValidatorScript := preload(
	"res://niveles/helpers/catalog/GameContentCatalogValidator.gd"
)

const BOOK_LEVEL_NEGATIVE_COUNT_KEY := "negative_count"
const BOOK_LEVEL_POSITIVE_COUNT_KEY := "positive_count"
const BOOK_LEVEL_MEAL_TEXTURE_PATH_KEY := "meal_texture_path"
const BOOK_LEVEL_CONDITION_TEXTURE_PATH_KEY := "condition_texture_path"
const BOOK_LEVEL_TEACHING_TEXTURE_PATH_KEY := "teaching_texture_path"
const BOOK_LEVEL_CATEGORY_KEY := "category"
const BOOK_LEVEL_COMPLETED_KEY := "completed"

var _texture_cache: Dictionary = {}
var _track_chapter_catalog: Dictionary = (
	GameTrackChapterCatalogScript.build_track_chapter_catalog()
)

var _track_books: Dictionary = _build_track_books()



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
	var chapters: Dictionary = _chapters_for_track(track_key)
	return chapters.size() if not chapters.is_empty() else fallback


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
	var chapters: Dictionary = _chapters_for_track(track_key)
	if not chapters.has(level_number) or not chapters[level_number] is Dictionary:
		return {}
	return (chapters[level_number] as Dictionary).duplicate(true)


func get_track_chapter_catalog() -> Dictionary:
	return _track_chapter_catalog.duplicate(true)


func get_track_chapter_definitions() -> Dictionary:
	return get_track_chapter_catalog()

func get_validation_issues() -> Array[String]:
	return GameContentCatalogValidatorScript.validate(_track_chapter_catalog)


func is_valid() -> bool:
	return get_validation_issues().is_empty()


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
	var chapters: Dictionary = _chapters_for_track(track_key)
	if chapters.is_empty():
		return book
	for level_number in _sorted_level_numbers(chapters):
		var first_run: Dictionary = get_chapter_run(track_key, level_number, 1)
		book[level_number] = {
			BOOK_LEVEL_NEGATIVE_COUNT_KEY: int(first_run.get(BOOK_LEVEL_NEGATIVE_COUNT_KEY, 0)),
			BOOK_LEVEL_POSITIVE_COUNT_KEY: int(first_run.get(BOOK_LEVEL_POSITIVE_COUNT_KEY, 0)),
			BOOK_LEVEL_MEAL_TEXTURE_PATH_KEY: str(
				first_run.get(BOOK_LEVEL_MEAL_TEXTURE_PATH_KEY, "")
			),
			BOOK_LEVEL_CONDITION_TEXTURE_PATH_KEY: str(
				first_run.get(BOOK_LEVEL_CONDITION_TEXTURE_PATH_KEY, "")
			),
			BOOK_LEVEL_TEACHING_TEXTURE_PATH_KEY: str(
				first_run.get(BOOK_LEVEL_TEACHING_TEXTURE_PATH_KEY, "")
			),
			BOOK_LEVEL_CATEGORY_KEY: str(first_run.get(BOOK_LEVEL_CATEGORY_KEY, "")),
			BOOK_LEVEL_COMPLETED_KEY: false
		}
	return book
func _chapters_for_track(track_key: String) -> Dictionary:
	var raw_chapters: Variant = _track_chapter_catalog.get(track_key, {})
	return raw_chapters if raw_chapters is Dictionary else {}


func _sorted_level_numbers(chapters: Dictionary) -> Array[int]:
	var level_numbers: Array[int] = []
	for raw_level_number in chapters.keys():
		level_numbers.append(int(raw_level_number))
	level_numbers.sort()
	return level_numbers
