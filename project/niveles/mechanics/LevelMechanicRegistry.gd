extends RefCounted


const LevelMechanicTypes := preload("res://niveles/mechanics/LevelMechanicTypes.gd")
const PLATE_SORT_MECHANIC_CONTROLLER_PATH := (
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
	var controllers: Dictionary = {}
	_register_controller(
		controllers,
		DEFAULT_MECHANIC_TYPE,
		PLATE_SORT_MECHANIC_CONTROLLER_PATH,
		level_manager
	)
	return controllers


static func _register_controller(
	controllers: Dictionary,
	mechanic_type: String,
	controller_script_path: String,
	level_manager
) -> void:
	var raw_controller_script: Variant = load(controller_script_path)
	if raw_controller_script == null:
		push_error(
			(
				"LevelMechanicRegistry no pudo cargar el controlador '%s' en %s."
			)
			% [mechanic_type, controller_script_path]
		)
		return

	if not raw_controller_script is Script:
		push_error(
			(
				"LevelMechanicRegistry cargo un recurso invalido para '%s' en %s."
			)
			% [mechanic_type, controller_script_path]
		)
		return

	var controller_script: Script = raw_controller_script
	if not controller_script.can_instantiate():
		push_error(
			(
				"LevelMechanicRegistry no puede instanciar '%s' en %s. Revisar errores de parseo o dependencias del script."
			)
			% [mechanic_type, controller_script_path]
		)
		return

	var controller = controller_script.new(level_manager)
	if controller == null:
		push_error(
			(
				"LevelMechanicRegistry no pudo instanciar el controlador '%s' en %s."
			)
			% [mechanic_type, controller_script_path]
		)
		return

	controllers[mechanic_type] = controller