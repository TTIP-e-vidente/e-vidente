extends Resource

class_name LevelItem


enum Condicion {KETO, CELIACO, VEGANO, DIABETICO, VEGETARIANO}

@export var condiciones:Array[Condicion]
@export var sprite:Texture2D
@export var escena:PackedScene
@export var posicion:Vector2
@export var esPositivo:bool
@export var info: Texture2D
@export var categoria : String
@export var allowed_track_keys: PackedStringArray = []
@export var blocked_track_keys: PackedStringArray = []


func is_explicitly_allowed_for_track(track_key: String) -> bool:
	return _contains_track_key(allowed_track_keys, track_key)


func is_explicitly_blocked_for_track(track_key: String) -> bool:
	return _contains_track_key(blocked_track_keys, track_key)


func has_condition(raw_condition: Variant) -> bool:
	return condiciones.has(int(raw_condition))


func has_any_condition(raw_conditions: Array) -> bool:
	for raw_condition in raw_conditions:
		if has_condition(raw_condition):
			return true
	return false


func _contains_track_key(track_keys: PackedStringArray, raw_track_key: String) -> bool:
	var clean_track_key := raw_track_key.strip_edges()
	if clean_track_key.is_empty():
		return false
	for track_key in track_keys:
		if str(track_key).strip_edges() == clean_track_key:
			return true
	return false

