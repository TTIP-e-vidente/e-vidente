extends RefCounted

# GameLevelContentCatalog.gd
# Fachada de lectura de capitulos legacy.
# Chapter = capitulo del libro; run = partida concreta dentro del capitulo.

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameTrackChapterDefinitionsScript := preload(
	"res://niveles/content/catalog/GameTrackChapterDefinitions.gd"
)
const GameChapterAssetCatalogScript := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)

const BOOK_LEVEL_COMPLETED_KEY := "completed"

var _chapters_by_track: Dictionary = {}


func _init() -> void:
	_chapters_by_track = GameTrackChapterDefinitionsScript.construir_catalogo_capitulo_pista()


func filtrar_elementos_por_categoria(items: Array, category_code: String) -> Array:
	if category_code.strip_edges().is_empty():
		return items.duplicate()
	var filtered_items: Array = []
	var wanted_category: String = GameTrackCatalog.normalizar_codigo_categoria(
		category_code
	)
	for item in items:
		if GameTrackCatalog.categorias_coinciden(str(item.categoria), wanted_category):
			filtered_items.append(item)
	return filtered_items


func obtener_pista_nivel_cantidad(track_key: String, fallback: int = 0) -> int:
	var track_chapters: Dictionary = _chapters_by_track.get(track_key, {})
	return track_chapters.size() if not track_chapters.is_empty() else fallback


func obtener_maximo_pista_nivel_cantidad(fallback: int = 0) -> int:
	var max_level_count := fallback
	for track_key in GameTrackCatalog.obtener_claves_pista():
		max_level_count = max(max_level_count, obtener_pista_nivel_cantidad(track_key, fallback))
	return max_level_count


func obtener_total_nivel_cantidad(fallback: int = 0) -> int:
	var total_levels := 0
	for track_key in GameTrackCatalog.obtener_claves_pista():
		total_levels += obtener_pista_nivel_cantidad(track_key, fallback)
	return total_levels


func obtener_capitulo_definicion(track_key: String, level_number: int) -> Dictionary:
	var track_chapters: Dictionary = _chapters_by_track.get(track_key, {})
	var chapter_definition: Dictionary = track_chapters.get(level_number, {})
	return chapter_definition.duplicate(true)


func obtener_capitulo_partida_cantidad(track_key: String, level_number: int) -> int:
	var chapter_definition: Dictionary = obtener_capitulo_definicion(track_key, level_number)
	var runs: Array = chapter_definition.get("runs", [])
	return runs.size()


func obtener_capitulo_partida_definicion(
	track_key: String,
	level_number: int,
	run_index: int = 1
) -> Dictionary:
	var chapter_definition: Dictionary = obtener_capitulo_definicion(track_key, level_number)
	var chapter_runs: Array = chapter_definition.get("runs", [])
	if chapter_runs.is_empty():
		return {}
	var resolved_run_index := clampi(run_index, 1, chapter_runs.size()) - 1
	var run_definition: Dictionary = chapter_runs[resolved_run_index]
	return run_definition.duplicate(true)


func resolver_textura(texture_ref: Variant) -> Texture2D:
	return GameChapterAssetCatalogScript.resolver_textura(texture_ref)


func construir_predeterminado_pista_progreso_estado() -> Dictionary:
	var progress_by_track: Dictionary = {}
	for track_key in GameTrackCatalog.obtener_claves_pista():
		progress_by_track[track_key] = construir_predeterminado_progreso_pista_por_pista(track_key)
	return progress_by_track


func construir_predeterminado_progreso_pista_por_pista(track_key: String) -> Dictionary:
	var track_progress: Dictionary = {}
	var track_chapters: Dictionary = _chapters_by_track.get(track_key, {})
	for raw_level_number in track_chapters.keys():
		track_progress[int(raw_level_number)] = {
			BOOK_LEVEL_COMPLETED_KEY: false
		}
	return track_progress
