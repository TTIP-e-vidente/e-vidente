extends RefCounted


const MEAL_TEXTURE_PATHS := {
	"desayuno": "res://assets-sistema/interfaz/desayuno.png",
	"almuerzo": "res://assets-sistema/interfaz/almuerzo.png",
	"cena": "res://assets-sistema/interfaz/cena.png",
	"bebida": "res://assets-sistema/interfaz/cena.png"
}

const CONDITION_TEXTURE_PATHS := {
	"prepara_celiaquia": "res://assets-sistema/interfaz/prepara-celiaquia.png",
	"prepara_vegane": "res://assets-sistema/interfaz/prepara-vegane.png",
	"prepara_vegan_gf": "res://assets-sistema/interfaz/prepara-vegan-gf.png",
	"prepara_keto": "res://assets-sistema/interfaz/prepara-keto.png"
}

const TEACHING_TEXTURE_PATHS := {
	"celiaquia_1": "res://assets-sistema/ensenanza/ensenanza-celiaquia-1.png",
	"celiaquia_2": "res://assets-sistema/ensenanza/ensenanza-celiaquia-2.png",
	"celiaquia_3": "res://assets-sistema/ensenanza/ensenanza-celiaquia-3.png",
	"celiaquia_4": "res://assets-sistema/ensenanza/ensenanza-celiaquia-4.png",
	"celiaquia_5": "res://assets-sistema/ensenanza/ensenanza-celiaquia-5.png",
	"celiaquia_6": "res://assets-sistema/ensenanza/ensenanza-celiaquia-6.png",
	"celiaquia_7": "res://assets-sistema/ensenanza/ensenanza-celiaquia-7.png",
	"celiaquia_8": "res://assets-sistema/ensenanza/ensenanza-celiaquia-8.png",
	"celiaquia_9": "res://assets-sistema/ensenanza/ensenanza-celiaquia-9.png",
	"vegan_vegetariane_1": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-1.png",
	"vegan_vegetariane_2": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-2.png",
	"vegan_vegetariane_3": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-3.png",
	"vegan_vegetariane_4": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-4.png",
	"vegan_vegetariane_5": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-5.png",
	"vegan_vegetariane_6": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-6.png",
	"vegan_vegetariane_7": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-7.png",
	"vegan_vegetariane_8": "res://assets-sistema/ensenanza/ensenanza-vegan-vegetariane-8.png",
	"keto_1": "res://assets-sistema/ensenanza/ensenanza-keto-1.png",
	"keto_2": "res://assets-sistema/ensenanza/ensenanza-keto-2.png",
	"keto_3": "res://assets-sistema/ensenanza/ensenanza-keto-3.png",
	"keto_4": "res://assets-sistema/ensenanza/ensenanza-keto-4.png",
	"keto_5": "res://assets-sistema/ensenanza/ensenanza-keto-5.png",
	"keto_6": "res://assets-sistema/ensenanza/ensenanza-keto-6.png"
}


static func get_meal_texture_path(meal_key: String) -> String:
	return _lookup_path(MEAL_TEXTURE_PATHS, meal_key)


static func get_condition_texture_path(condition_key: String) -> String:
	return _lookup_path(CONDITION_TEXTURE_PATHS, condition_key)


static func get_teaching_texture_path(teaching_key: String) -> String:
	return _lookup_path(TEACHING_TEXTURE_PATHS, teaching_key)


static func _lookup_path(path_map: Dictionary, raw_key: String) -> String:
	var clean_key := raw_key.strip_edges().to_lower()
	if clean_key.is_empty():
		return ""
	return str(path_map.get(clean_key, ""))