# Estrella de precisión — fill vertical de abajo hacia arriba.
@tool
extends Node2D
class_name StarProgress

const N_POINTS: int = 5

@export var star_radius: float = 13.0
@export var inner_ratio: float = 0.42
@export var border_width: float = 1.5
@export var star_base_color: Color = Color(1.0, 1.0, 1.0, 0.0)
@export var star_fill_color: Color = Color(1.0, 0.68, 0.05, 1.0)
@export var border_color: Color = Color(0.42, 0.42, 0.42, 1.0)

@export_range(0.0, 1.0, 0.01) var progress: float = 0.0:
	set(new_value):
		progress = clampf(new_value, 0.0, 1.0)
		queue_redraw()

var _tween: Tween = null


func set_progress(new_value: float, animated: bool = false) -> void:
	var clamped_value := clampf(new_value, 0.0, 1.0)
	if animated:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "progress", clamped_value, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		progress = clamped_value


func _draw() -> void:
	var star_pts := _build_star_points(star_radius, star_radius * inner_ratio)
	draw_colored_polygon(star_pts, star_base_color)
	if progress > 0.0:
		_draw_fill(star_pts)
	var border_pts := PackedVector2Array(star_pts)
	border_pts.append(star_pts[0])
	draw_polyline(border_pts, border_color, border_width, true)


func _draw_fill(star_pts: PackedVector2Array) -> void:
	var min_x := star_pts[0].x
	var max_x := star_pts[0].x
	var min_y := star_pts[0].y
	var max_y := star_pts[0].y
	for pt: Vector2 in star_pts:
		if pt.x < min_x: min_x = pt.x
		if pt.x > max_x: max_x = pt.x
		if pt.y < min_y: min_y = pt.y
		if pt.y > max_y: max_y = pt.y

	var fill_y: float = lerp(max_y, min_y, progress)
	var clip_rect := PackedVector2Array([
		Vector2(min_x - 1.0, fill_y),
		Vector2(max_x + 1.0, fill_y),
		Vector2(max_x + 1.0, max_y + 1.0),
		Vector2(min_x - 1.0, max_y + 1.0),
	])
	var result: Array[PackedVector2Array] = Geometry2D.intersect_polygons(star_pts, clip_rect)
	for poly: PackedVector2Array in result:
		if poly.size() >= 3:
			draw_colored_polygon(poly, star_fill_color)


func _build_star_points(outer_r: float, inner_r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(N_POINTS * 2):
		var angle := (TAU / float(N_POINTS * 2)) * float(i) - PI / 2.0
		var r := outer_r if i % 2 == 0 else inner_r
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return pts
