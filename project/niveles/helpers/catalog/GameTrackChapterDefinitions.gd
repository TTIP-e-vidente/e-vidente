extends RefCounted


const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")
const GameChapterAssetCatalog := preload("res://niveles/helpers/catalog/GameChapterAssetCatalog.gd")


static func build_track_chapter_definitions() -> Dictionary:
	return {
		"celiaquia": _build_celiaquia_definitions(),
		"veganismo": _build_veganismo_definitions(),
		"veganismo_celiaquia": _build_veganismo_celiaquia_definitions(),
		"cetogenica": _build_cetogenica_definitions()
	}


static func _build_celiaquia_definitions() -> Dictionary:
	return {
		1: {"runs": [
			_build_plate_sort_run(1, 1, "almuerzo", "prepara_celiaquia", "celiaquia_1", GameTrackCatalog.CATEGORY_ALMUERZO_CENA),
			_build_plate_sort_run(1, 1, "desayuno", "prepara_celiaquia", "celiaquia_2", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)
		]},
		2: {"runs": [
			_build_plate_sort_run(2, 3, "desayuno", "prepara_celiaquia", "celiaquia_2", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA),
			_build_plate_sort_run(1, 2, "bebida", "prepara_celiaquia", "celiaquia_7", GameTrackCatalog.CATEGORY_BEBIDA)
		]},
		3: {"runs": [_build_plate_sort_run(2, 3, "cena", "prepara_celiaquia", "celiaquia_6", GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		4: {"runs": [_build_plate_sort_run(3, 3, "desayuno", "prepara_celiaquia", "celiaquia_8", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)]},
		5: {"runs": [_build_plate_sort_run(4, 2, "almuerzo", "prepara_celiaquia", "celiaquia_5", GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		6: {"runs": [_build_plate_sort_run(1, 3, "bebida", "prepara_celiaquia", "celiaquia_7", GameTrackCatalog.CATEGORY_BEBIDA)]}
	}


static func _build_veganismo_definitions() -> Dictionary:
	return {
		1: {"runs": [
			_build_plate_sort_run(1, 2, "almuerzo", "prepara_vegane", "vegan_vegetariane_1", GameTrackCatalog.CATEGORY_ALMUERZO_CENA),
			_build_plate_sort_run(1, 1, "desayuno", "prepara_vegane", "vegan_vegetariane_2", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)
		]},
		2: {"runs": [
			_build_plate_sort_run(2, 2, "desayuno", "prepara_vegane", "vegan_vegetariane_2", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA),
			_build_plate_sort_run(1, 2, "bebida", "prepara_vegane", "vegan_vegetariane_6", GameTrackCatalog.CATEGORY_BEBIDA)
		]},
		3: {"runs": [_build_plate_sort_run(2, 3, "cena", "prepara_vegane", "vegan_vegetariane_3", GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		4: {"runs": [_build_plate_sort_run(2, 4, "desayuno", "prepara_vegane", "vegan_vegetariane_4", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)]},
		5: {"runs": [_build_plate_sort_run(4, 2, "almuerzo", "prepara_vegane", "vegan_vegetariane_5", GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		6: {"runs": [_build_plate_sort_run(1, 3, "bebida", "prepara_vegane", "vegan_vegetariane_6", GameTrackCatalog.CATEGORY_BEBIDA)]}
	}


static func _build_veganismo_celiaquia_definitions() -> Dictionary:
	return {
		1: {"runs": [
			_build_plate_sort_run(1, 1, "almuerzo", "prepara_vegan_gf", "celiaquia_3", GameTrackCatalog.CATEGORY_ALMUERZO_CENA),
			_build_plate_sort_run(1, 1, "desayuno", "prepara_vegan_gf", "vegan_vegetariane_7", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)
		]},
		2: {"runs": [
			_build_plate_sort_run(1, 2, "desayuno", "prepara_vegan_gf", "vegan_vegetariane_7", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA),
			_build_plate_sort_run(1, 1, "bebida", "prepara_vegan_gf", "celiaquia_7", GameTrackCatalog.CATEGORY_BEBIDA)
		]},
		3: {"runs": [_build_plate_sort_run(2, 4, "cena", "prepara_vegan_gf", "celiaquia_4", GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		4: {"runs": [_build_plate_sort_run(4, 2, "desayuno", "prepara_vegan_gf", "vegan_vegetariane_8", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)]},
		5: {"runs": [_build_plate_sort_run(4, 2, "almuerzo", "prepara_vegan_gf", "celiaquia_9", GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		6: {"runs": [_build_plate_sort_run(2, 2, "bebida", "prepara_vegan_gf", "celiaquia_7", GameTrackCatalog.CATEGORY_BEBIDA)]}
	}


static func _build_cetogenica_definitions() -> Dictionary:
	return {
		1: {"runs": [_build_plate_sort_run(1, 1, "almuerzo", "prepara_keto", "keto_1", GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		2: {"runs": [_build_plate_sort_run(1, 2, "desayuno", "prepara_keto", "keto_2", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)]},
		3: {"runs": [_build_plate_sort_run(2, 4, "cena", "prepara_keto", "keto_3", GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		4: {"runs": [_build_plate_sort_run(4, 2, "desayuno", "prepara_keto", "keto_4", GameTrackCatalog.CATEGORY_DESAYUNO_MERIENDA)]},
		5: {"runs": [_build_plate_sort_run(4, 2, "almuerzo", "prepara_keto", "keto_5", GameTrackCatalog.CATEGORY_ALMUERZO_CENA)]},
		6: {"runs": [_build_plate_sort_run(2, 2, "bebida", "prepara_keto", "keto_6", GameTrackCatalog.CATEGORY_BEBIDA)]}
	}


static func _build_plate_sort_run(negative_count: int, positive_count: int, meal_key: String, condition_key: String, teaching_key: String, category: String) -> Dictionary:
	var meal_texture_path := GameChapterAssetCatalog.get_meal_texture_path(meal_key)
	var condition_texture_path := GameChapterAssetCatalog.get_condition_texture_path(condition_key)
	var teaching_texture_path := GameChapterAssetCatalog.get_teaching_texture_path(teaching_key)
	var mechanic_payload := {
		"negative_count": negative_count,
		"positive_count": positive_count,
		"category": category
	}
	return {
		"mechanic_type": LevelMechanicTypes.PLATE_SORT,
		"mechanic_payload": mechanic_payload,
		"negative_count": negative_count,
		"positive_count": positive_count,
		"teaching_key": teaching_key,
		"meal_texture_path": meal_texture_path,
		"condition_texture_path": condition_texture_path,
		"teaching_texture_path": teaching_texture_path,
		"category": category
	}