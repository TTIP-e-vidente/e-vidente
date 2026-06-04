@tool
# Badge de progreso para nodos del mapa.
# Composición: CheckBadge (arriba) + StarProgress (abajo).
extends Node2D
class_name NodeProgressBadge

@onready var _star: StarProgress  = $StarProgress


func establecer_completado(value: bool) -> void:
	visible = value


func establecer_progreso(value: float, animated: bool = false) -> void:
	if not visible:
		return
	if _star != null:
		_star.establecer_progreso(value, animated)


# ── Debug (solo editor) ────────────────────────────────────────────────────────
@export_group("Debug")
@export var debug_completed: bool = false:
	set(v):
		debug_completed = v
		if is_node_ready():
			establecer_completado(v)

@export_range(0.0, 1.0, 0.05) var debug_progress: float = 1.0:
	set(v):
		debug_progress = v
		if is_node_ready() and visible and _star != null:
			_star.establecer_progreso(v)
