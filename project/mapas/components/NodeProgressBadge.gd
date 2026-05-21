# Badge de progreso para nodos del mapa.
# Composición: CheckBadge (arriba) + StarProgress (abajo).
@tool
extends Node2D
class_name NodeProgressBadge

@onready var _check: CheckBadge   = $CheckBadge
@onready var _star: StarProgress  = $StarProgress


func set_completed(value: bool) -> void:
	visible = value
	if _check != null:
		_check.completed = value


func set_progress(value: float, animated: bool = false) -> void:
	if not visible:
		return
	if _star != null:
		_star.set_progress(value, animated)
