# Estrella de precisión — dibujada con draw_*(), sin texturas externas.
# fill horizontal real: 0 % = vacía, 100 % = dorada completa.
@tool
extends Node2D
class_name StarProgress

const OUTER_RADIUS: float = 13.0
const INNER_RADIUS: float  = 5.5
const N_POINTS: int        = 5
const COLOR_EMPTY: Color   = Color(0.82, 0.82, 0.82, 0.75)
const COLOR_FILL: Color    = Color(1.0, 0.74, 0.10, 1.0)
const COLOR_BORDER: Color  = Color(0.28, 0.20, 0.05, 1.0)
const COLOR_SHADOW: Color  = Color(0.0, 0.0, 0.0, 0.28)
const BORDER_W: float      = 1.4

@export_range(0.0, 1.0, 0.01) var progress: float = 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()

var _tween: Tween = null


func set_progress(value: float, animated: bool = false) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if animated:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "progress", clamped, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		progress = clamped


func _draw() -> void:
	var pts := _star_polygon(Vector2.ZERO, OUTER_RADIUS, INNER_RADIUS, N_POINTS)
	# Sombra de fondo para contraste sobre el mapa
	draw_circle(Vector2.ZERO, OUTER_RADIUS + 3.0, COLOR_SHADOW)
	# Estrella base gris
	draw_colored_polygon(pts, COLOR_EMPTY)
	# Relleno dorado proporcional
	if progress > 0.001:
		var clip_x := OUTER_RADIUS * (2.0 * progress - 1.0)
		var filled := _clip_left(pts, clip_x)
		if filled.size() >= 3:
			draw_colored_polygon(filled, COLOR_FILL)
	# Borde fino
	var border := pts
	border.append(pts[0])
	draw_polyline(border, COLOR_BORDER, BORDER_W, true)


static func _star_polygon(
	center: Vector2,
	outer_r: float,
	inner_r: float,
	n: int
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(n * 2):
		var angle := (TAU / float(n * 2)) * float(i) - PI / 2.0
		var r := outer_r if i % 2 == 0 else inner_r
		pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	return pts


# Sutherland-Hodgman de un plano: conserva solo la parte con x <= clip_x.
static func _clip_left(
	polygon: PackedVector2Array,
	clip_x: float
) -> PackedVector2Array:
	var output := PackedVector2Array()
	var n := polygon.size()
	if n == 0:
		return output
	for i: int in range(n):
		var cur := polygon[i]
		var nxt := polygon[(i + 1) % n]
		var cur_in := cur.x <= clip_x
		var nxt_in := nxt.x <= clip_x
		if cur_in:
			output.append(cur)
		if cur_in != nxt_in:
			var t := (clip_x - cur.x) / (nxt.x - cur.x)
			output.append(cur.lerp(nxt, t))
	return output
