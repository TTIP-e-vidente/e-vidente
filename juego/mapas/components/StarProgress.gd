@tool
# Estrella de precisión — fill vertical de abajo hacia arriba.
extends Node2D
class_name StarProgress

const N_POINTS: int = 5

@export var star_radius: float = 13.0
@export var inner_ratio: float = 0.42
@export var star_base_color: Color = Color(0.6, 0.6, 0.6, 1.0)
@export var star_fill_color: Color = Color(1.0, 0.68, 0.05, 1.0)

@export_range(0.0, 1.0, 0.01) var progress: float = 0.0:
	set(new_value):
		progress = clampf(new_value, 0.0, 1.0)
		queue_redraw()

var _tween: Tween = null


func establecer_progreso(new_value: float, animated: bool = false) -> void:
	var clamped_value: float = clampf(new_value, 0.0, 1.0)
	print_debug("[Star] establecer_progreso percent=", clamped_value)
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

	# fill_y calculado por bisectón para que el área rellenada sea exactamente progress * área_total
	var fill_y: float = _area_fill_y(star_pts, progress, min_x, max_x, min_y, max_y)
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


# Bisectón: encuentra el fill_y tal que el área recortada / área total == target_ratio.
# Invariante: ratio(lo) >= target >= ratio(hi)  con  lo <= hi en coordenadas Y de pantalla.
func _area_fill_y(
	star_pts: PackedVector2Array,
	target_ratio: float,
	min_x: float,
	max_x: float,
	min_y: float,
	max_y: float
) -> float:
	var total_area := _polygon_area(star_pts)
	if total_area < 0.001:
		return lerp(max_y, min_y, target_ratio)

	var lo := min_y  # fill_y en el tope → ratio ≈ 1.0
	var hi := max_y  # fill_y en el fondo → ratio ≈ 0.0
	for i_bisect: int in range(16):
		var mid := (lo + hi) * 0.5
		var clip := PackedVector2Array([
			Vector2(min_x - 1.0, mid),
			Vector2(max_x + 1.0, mid),
			Vector2(max_x + 1.0, max_y + 1.0),
			Vector2(min_x - 1.0, max_y + 1.0),
		])
		var polys: Array[PackedVector2Array] = Geometry2D.intersect_polygons(star_pts, clip)
		var clipped_area := 0.0
		for poly: PackedVector2Array in polys:
			clipped_area += _polygon_area(poly)
		if clipped_area / total_area > target_ratio:
			lo = mid  # demasiado área → subir fill_y (menos relleno)
		else:
			hi = mid  # poco área → bajar fill_y (más relleno)
	return (lo + hi) * 0.5


# Fórmula del cordón de zapatero para calcular el área de un polígono.
func _polygon_area(pts: PackedVector2Array) -> float:
	var area := 0.0
	var n := pts.size()
	for i: int in range(n):
		var j: int = (i + 1) % n
		area += pts[i].x * pts[j].y
		area -= pts[j].x * pts[i].y
	return absf(area) * 0.5


func _build_star_points(outer_r: float, inner_r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(N_POINTS * 2):
		var angle := (TAU / float(N_POINTS * 2)) * float(i) - PI / 2.0
		var r := outer_r if i % 2 == 0 else inner_r
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return pts
