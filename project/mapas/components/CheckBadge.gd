# Indicador de nodo completado: círculo con check blanco.
@tool
extends Node2D
class_name CheckBadge

const RADIUS: float     = 10.0
const BORDER_W: float   = 1.5
const SHADOW_R: float   = RADIUS + 3.0
const COLOR_DONE: Color  = Color("#4CAF50")
const COLOR_IDLE: Color  = Color(0.45, 0.45, 0.5, 0.55)
const COLOR_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.30)
const COLOR_CHECK: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var completed: bool = false:
	set(v):
		completed = v
		queue_redraw()


func _draw() -> void:
	# Sombra de fondo para contraste sobre el mapa
	draw_circle(Vector2.ZERO, SHADOW_R, COLOR_SHADOW)
	var bg: Color = COLOR_DONE if completed else COLOR_IDLE
	draw_circle(Vector2.ZERO, RADIUS, bg)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, bg.darkened(0.25), BORDER_W)
	if completed:
		_draw_check()


func _draw_check() -> void:
	var pts := PackedVector2Array([
		Vector2(-4.5,  0.5),
		Vector2(-1.5,  4.0),
		Vector2( 5.0, -4.0),
	])
	draw_polyline(pts, COLOR_CHECK, 2.2, true)
