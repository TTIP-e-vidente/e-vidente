# Badge de progreso para nodos del mapa.
# Composición: CheckBadge (arriba) + StarProgress (abajo).
@tool
extends Node2D
class_name NodeProgressBadge

@onready var _star: StarProgress  = $StarProgress


func set_completed(value: bool) -> void:
	visible = value


func set_progress(value: float, animated: bool = false) -> void:
	if not visible:
		return
	if _star != null:
		_star.set_progress(value, animated)


# ── Debug (solo editor) ────────────────────────────────────────────────────────
@export_group("Debug")
@export var debug_completed: bool = false:
	set(v):
		debug_completed = v
		if is_node_ready():
			set_completed(v)

@export_range(0.0, 1.0, 0.05) var debug_progress: float = 1.0:
	set(v):
		debug_progress = v
		if is_node_ready() and visible and _star != null:
			_star.set_progress(v)
