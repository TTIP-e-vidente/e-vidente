extends RefCounted
class_name LevelMechanicController

var _manager


func _init(manager) -> void:
	_manager = manager


func get_mechanic_type() -> String:
	return ""


func configure_run(_run_data: Dictionary, _level_resource: LevelResource) -> void:
	pass


func restore_or_start(_saved_level_state: Dictionary) -> void:
	pass


func build_partial_state() -> Dictionary:
	return {}


func build_partial_summary(_partial_state: Dictionary) -> Dictionary:
	return {}


func get_progress_count() -> int:
	return 0


func clear_runtime_state() -> void:
	pass
