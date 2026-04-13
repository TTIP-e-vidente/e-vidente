extends RefCounted


const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")
const PlateSortMechanicControllerScript := preload(
	"res://niveles/mechanics/PlateSortMechanicController.gd"
)

const DEFAULT_MECHANIC_TYPE := LevelMechanicTypes.PLATE_SORT


static func get_default_mechanic_type() -> String:
	return DEFAULT_MECHANIC_TYPE


static func normalize_mechanic_type(
	raw_mechanic_type: Variant,
	fallback: String = DEFAULT_MECHANIC_TYPE
) -> String:
	var clean_mechanic_type: String = str(raw_mechanic_type).strip_edges()
	if clean_mechanic_type.is_empty():
		return fallback
	return clean_mechanic_type


static func has_mechanic_type(raw_mechanic_type: Variant) -> bool:
	return normalize_mechanic_type(raw_mechanic_type, "") == DEFAULT_MECHANIC_TYPE


static func build_controllers(level_manager) -> Dictionary:
	return {
		DEFAULT_MECHANIC_TYPE: PlateSortMechanicControllerScript.new(level_manager)
	}