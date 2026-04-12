extends RefCounted


const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")
const PlateSortMechanicControllerScript := preload(
	"res://niveles/mechanics/PlateSortMechanicController.gd"
)

const CONTROLLER_SCRIPT_BY_TYPE := {
	LevelMechanicTypes.PLATE_SORT: PlateSortMechanicControllerScript
}


static func get_default_mechanic_type() -> String:
	return LevelMechanicTypes.PLATE_SORT


static func normalize_mechanic_type(
	raw_mechanic_type: Variant,
	fallback: String = LevelMechanicTypes.PLATE_SORT
) -> String:
	var clean_mechanic_type: String = str(raw_mechanic_type).strip_edges()
	if clean_mechanic_type.is_empty():
		return fallback
	return clean_mechanic_type


static func has_mechanic_type(raw_mechanic_type: Variant) -> bool:
	var clean_mechanic_type: String = normalize_mechanic_type(raw_mechanic_type, "")
	return (
		not clean_mechanic_type.is_empty()
		and CONTROLLER_SCRIPT_BY_TYPE.has(clean_mechanic_type)
	)


static func get_supported_types() -> Array:
	return CONTROLLER_SCRIPT_BY_TYPE.keys().duplicate()


static func build_controllers(level_manager) -> Dictionary:
	var controllers: Dictionary = {}
	for mechanic_type in get_supported_types():
		var controller_script = CONTROLLER_SCRIPT_BY_TYPE.get(mechanic_type)
		if controller_script == null:
			continue
		controllers[mechanic_type] = controller_script.new(level_manager)
	return controllers