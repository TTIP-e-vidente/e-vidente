# Indicador de nodo completado: círculo con check blanco.
@tool
extends Node2D
class_name CheckBadge

const RADIUS: float        = 10.0
const BORDER_W: float      = 1.5
const COLOR_CIRCLE: Color  = Color(0.24, 0.72, 0.28, 1.0)
const COLOR_BORDER: Color  = Color(0.12, 0.45, 0.16, 1.0)
const COLOR_CHECK: Color   = Color(1.0, 1.0, 1.0, 1.0)

@export var completed: bool = false:
	set(v):
		completed = v
		queue_redraw()


func _draw() -> void:
	if not completed:
		return
	draw_circle(Vector2.ZERO, RADIUS, COLOR_CIRCLE)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, COLOR_BORDER, BORDER_W)
	_draw_check()


func _draw_check() -> void:
	var pts := PackedVector2Array([
		Vector2(-4.5,  0.5),
		Vector2(-1.5,  4.0),
		Vector2( 5.0, -4.0),
	])
	draw_polyline(pts, COLOR_CHECK, 3.0, true)
