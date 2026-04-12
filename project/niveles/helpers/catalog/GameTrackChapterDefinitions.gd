extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameChapterAssetCatalog := preload(
	"res://niveles/helpers/catalog/GameChapterAssetCatalog.gd"
)
const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")

const CATEGORY_MEAL := GameTrackCatalog.CATEGORY_ALMUERZO_CENA
const CATEGORY_BREAKFAST := GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA
const CATEGORY_DRINK := GameTrackCatalog.CATEGORY_BEBIDA

static func build_track_chapter_catalog() -> Dictionary:
	var chapter_catalog: Dictionary = {}
	var chapter_blueprints_by_track: Dictionary = _build_track_chapter_blueprints()
	for track_key in _ordered_track_keys(chapter_blueprints_by_track):
		chapter_catalog[track_key] = _build_chapter_catalog_for_track(
			track_key,
			chapter_blueprints_by_track.get(track_key, [])
		)
	return chapter_catalog


static func _build_track_chapter_blueprints() -> Dictionary:
	return {
		GameTrackCatalog.TRACK_CELIAQUIA: _build_celiaquia_chapters(),
		GameTrackCatalog.TRACK_VEGANISMO: _build_veganismo_chapters(),
		GameTrackCatalog.TRACK_VEGANISMO_CELIAQUIA: _build_veganismo_celiaquia_chapters(),
		GameTrackCatalog.TRACK_CETOGENICA: _build_cetogenica_chapters()
	}


static func _ordered_track_keys(chapter_blueprints_by_track: Dictionary) -> Array:
	var track_keys: Array = GameTrackCatalog.get_track_keys().duplicate()
	for raw_track_key in chapter_blueprints_by_track.keys():
		var track_key: String = str(raw_track_key).strip_edges()
		if track_key.is_empty() or track_keys.has(track_key):
			continue
		track_keys.append(track_key)
	return track_keys


static func _build_celiaquia_chapters() -> Array:
	return [
		_chapter("almuerzo", "celiaquia_1", CATEGORY_MEAL, 1, 1),
		_chapter("desayuno", "celiaquia_2", CATEGORY_BREAKFAST, 2, 3),
		_chapter("cena", "celiaquia_6", CATEGORY_MEAL, 2, 3),
		_chapter("desayuno", "celiaquia_8", CATEGORY_BREAKFAST, 3, 3),
		_chapter("almuerzo", "celiaquia_5", CATEGORY_MEAL, 4, 2),
		_chapter("bebida", "celiaquia_7", CATEGORY_DRINK, 1, 3)
	]


static func _build_veganismo_chapters() -> Array:
	return [
		_chapter("almuerzo", "vegan_vegetariane_1", CATEGORY_MEAL, 1, 2),
		_chapter("desayuno", "vegan_vegetariane_2", CATEGORY_BREAKFAST, 2, 2),
		_chapter("cena", "vegan_vegetariane_3", CATEGORY_MEAL, 2, 3),
		_chapter("desayuno", "vegan_vegetariane_4", CATEGORY_BREAKFAST, 2, 4),
		_chapter("almuerzo", "vegan_vegetariane_5", CATEGORY_MEAL, 4, 2),
		_chapter("bebida", "vegan_vegetariane_6", CATEGORY_DRINK, 1, 3)
	]


static func _build_veganismo_celiaquia_chapters() -> Array:
	return [
		_chapter("almuerzo", "celiaquia_3", CATEGORY_MEAL, 1, 1),
		_chapter("desayuno", "vegan_vegetariane_7", CATEGORY_BREAKFAST, 1, 2),
		_chapter("cena", "celiaquia_4", CATEGORY_MEAL, 2, 4),
		_chapter("desayuno", "vegan_vegetariane_8", CATEGORY_BREAKFAST, 4, 2),
		_chapter("almuerzo", "celiaquia_9", CATEGORY_MEAL, 4, 2),
		_chapter("bebida", "celiaquia_7", CATEGORY_DRINK, 2, 2)
	]


static func _build_cetogenica_chapters() -> Array:
	return [
		_chapter("almuerzo", "keto_1", CATEGORY_MEAL, 1, 1),
		_chapter("desayuno", "keto_2", CATEGORY_BREAKFAST, 1, 2),
		_chapter("cena", "keto_3", CATEGORY_MEAL, 2, 4),
		_chapter("desayuno", "keto_4", CATEGORY_BREAKFAST, 4, 2),
		_chapter("almuerzo", "keto_5", CATEGORY_MEAL, 4, 2),
		_chapter("bebida", "keto_6", CATEGORY_DRINK, 2, 2)
	]


static func _chapter(
	meal_key: String,
	teaching_key: String,
	category: String,
	negative_count: int,
	positive_count: int
) -> Dictionary:
	return {
		"runs": [
			_run_blueprint(
				meal_key,
				teaching_key,
				category,
				negative_count,
				positive_count
			)
		]
	}


static func _run_blueprint(
	meal_key: String,
	teaching_key: String,
	category: String,
	negative_count: int,
	positive_count: int
) -> Dictionary:
	return {
		"meal_key": meal_key,
		"teaching_key": teaching_key,
		"category": category,
		"negative_count": negative_count,
		"positive_count": positive_count
	}


static func _build_chapter_catalog_for_track(
	track_key: String,
	raw_chapter_blueprints: Variant
) -> Dictionary:
	var chapter_catalog: Dictionary = {}
	if not raw_chapter_blueprints is Array:
		return chapter_catalog
	var chapter_blueprints: Array = raw_chapter_blueprints
	for chapter_index in range(chapter_blueprints.size()):
		var chapter_blueprint: Variant = chapter_blueprints[chapter_index]
		if not chapter_blueprint is Dictionary:
			continue
		chapter_catalog[chapter_index + 1] = _build_chapter_definition(
			track_key,
			chapter_blueprint
		)
	return chapter_catalog


static func _build_chapter_definition(
	track_key: String,
	chapter_blueprint: Dictionary
) -> Dictionary:
	var runs: Array = []
	for raw_run_blueprint in _resolve_run_blueprints(chapter_blueprint):
		if not raw_run_blueprint is Dictionary:
			continue
		runs.append(_build_plate_sort_run_definition(track_key, raw_run_blueprint))
	return {"runs": runs}


static func _resolve_run_blueprints(chapter_blueprint: Dictionary) -> Array:
	var raw_runs: Variant = chapter_blueprint.get("runs", [])
	if raw_runs is Array and not raw_runs.is_empty():
		return (raw_runs as Array).duplicate(true)
	return [chapter_blueprint.duplicate(true)]


static func _build_plate_sort_run_definition(
	track_key: String,
	run_blueprint: Dictionary
) -> Dictionary:
	var meal_key: String = str(run_blueprint.get("meal_key", ""))
	var teaching_key: String = str(run_blueprint.get("teaching_key", ""))
	var category: String = str(run_blueprint.get("category", ""))
	var negative_count: int = int(run_blueprint.get("negative_count", 0))
	var positive_count: int = int(run_blueprint.get("positive_count", 0))
	var asset_paths: Dictionary = GameChapterAssetCatalog.build_run_asset_paths(
		track_key,
		meal_key,
		teaching_key
	)
	return {
		"mechanic_type": LevelMechanicTypes.PLATE_SORT,
		"mechanic_payload": _build_plate_sort_payload(
			negative_count,
			positive_count,
			category
		),
		"negative_count": negative_count,
		"positive_count": positive_count,
		"teaching_key": teaching_key,
		"meal_texture_path": str(asset_paths.get("meal_texture_path", "")),
		"condition_texture_path": str(asset_paths.get("condition_texture_path", "")),
		"teaching_texture_path": str(asset_paths.get("teaching_texture_path", "")),
		"category": category
	}


static func _build_plate_sort_payload(
	negative_count: int,
	positive_count: int,
	category: String
) -> Dictionary:
	return {
		"negative_count": negative_count,
		"positive_count": positive_count,
		"category": category
	}
