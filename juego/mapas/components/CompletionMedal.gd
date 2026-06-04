@tool
# Medalla compacta de completado.
# Dibuja con _draw(): círculo verde + check blanco + mini estrella de precisión (discreta).
# No usa texturas externas ni nodos hijos.
extends Node2D
class_name CompletionMedal

# ── Dimensiones ────────────────────────────────────────────────────────────────
const CIRCLE_R:    float   = 11.0        # Radio del círculo principal
const BORDER_W:    float   = 1.5         # Grosor del borde del círculo
const STAR_POS:    Vector2 = Vector2(9.0, 8.0)  # Centro estrella (esquina inf-derecha)
const STAR_OUTER:  float   = 7.5         # Radio exterior de la estrella
const STAR_INNER:  float   = 3.2         # Radio interior de la estrella
const STAR_RING_R: float   = 8.5         # Anillo blanco separador detrás de la estrella
const STAR_N:      int     = 5

# ── Colores: medallón ──────────────────────────────────────────────────────────
const C_GREEN:     Color = Color(0.22, 0.70, 0.28, 1.0)
const C_GREEN_BDR: Color = Color(0.08, 0.38, 0.12, 1.0)
const C_CHECK:     Color = Color(1.0,  1.0,  1.0,  1.0)

# ── Colores: estrella ──────────────────────────────────────────────────────────
const C_STAR_BASE: Color = Color(0.82, 0.82, 0.82, 1.0)
const C_STAR_FILL: Color = Color(1.0,  0.72, 0.10, 1.0)
const C_STAR_BDR:  Color = Color(0.32, 0.20, 0.04, 1.0)
const C_STAR_RING: Color = Color(1.0,  1.0,  1.0,  1.0)
const C_STAR_PEAK: Color = Color(1.0,  0.88, 0.22, 1.0)  # Dorado brillante en tier 5
const C_STAR_GLOW: Color = Color(1.0,  0.96, 0.55, 0.85) # Brillo central en 100%

# ── Estado runtime ─────────────────────────────────────────────────────────────
@export var progress: float = 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()

@export var completed: bool = false:
	set(v):
		completed = v
		queue_redraw()

# ── Debug (solo editor) ────────────────────────────────────────────────────────
@export_group("Debug")
@export var debug_completed: bool = false:
	set(v):
		debug_completed = v
		if Engine.is_editor_hint():
			visible = v
		queue_redraw()

@export_range(0.0, 1.0, 0.25) var debug_progress: float = 1.0:
	set(v):
		debug_progress = v
		queue_redraw()

# ── API pública ────────────────────────────────────────────────────────────────
func establecer_completado(value: bool) -> void:
	completed = value
	visible   = value
	queue_redraw()


func establecer_progreso(value: float, _animated: bool = false) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


# ── Dibujo ─────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var should_show: bool = completed or (Engine.is_editor_hint() and debug_completed)
	if not should_show:
		return

	var eff: float = debug_progress if Engine.is_editor_hint() else progress
	var tier: int  = _get_fill_tier(eff)

	# 1. Círculo verde principal
	draw_circle(Vector2.ZERO, CIRCLE_R, C_GREEN)
	draw_arc(Vector2.ZERO, CIRCLE_R, 0.0, TAU, 32, C_GREEN_BDR, BORDER_W)

	# 2. Check blanco centrado
	_draw_verificar()

	# 3. Anillo blanco separador para la estrella (la aísla del verde)
	draw_circle(STAR_POS, STAR_RING_R, C_STAR_RING)

	# 4. Mini estrella de precisión (6 tiers visuales inequívocos)
	_draw_star(STAR_POS, tier)


func _draw_verificar() -> void:
	var pts := PackedVector2Array([
		Vector2(-5.0,  0.0),
		Vector2(-1.5,  4.0),
		Vector2( 5.5, -4.5),
	])
	draw_polyline(pts, C_CHECK, 3.0, true)


func _draw_star(center: Vector2, tier: int) -> void:
	var pts := _star_polygon(center, STAR_OUTER, STAR_INNER, STAR_N)

	# Base gris siempre visible
	draw_colored_polygon(pts, C_STAR_BASE)

	# Puntas doradas: cada punta = 1 tier (0 a 5)
	if tier > 0:
		var fill_col: Color = C_STAR_PEAK if tier == STAR_N else C_STAR_FILL
		for t: int in range(min(tier, STAR_N)):
			draw_colored_polygon(_tip_polygon(pts, t), fill_col)

	# Brillo central extra solo en 100 %
	if tier == STAR_N:
		var glow := _star_polygon(center, STAR_OUTER * 0.42, STAR_INNER * 0.42, STAR_N)
		draw_colored_polygon(glow, C_STAR_GLOW)

	# Borde oscuro definido
	var border := PackedVector2Array(pts)
	border.append(pts[0])
	draw_polyline(border, C_STAR_BDR, 1.4, true)


# ── Helpers estáticos ──────────────────────────────────────────────────────────

# Convierte progreso a tier visual: 0=vacío, 1-4=parcial, 5=completa.
static func _get_fill_tier(p: float) -> int:
	if p >= 1.0:  return 5
	if p >= 0.75: return 4
	if p >= 0.50: return 3
	if p >= 0.25: return 2
	if p >  0.0:  return 1
	return 0


# Triángulo de la punta tip_idx (0 = cima, sentido horario).
# star_pts tiene 10 vértices: alternados outer/inner.
static func _tip_polygon(star_pts: PackedVector2Array, tip_idx: int) -> PackedVector2Array:
	var n     := star_pts.size()  # 10
	var outer := tip_idx * 2
	var left  := (outer - 1 + n) % n
	var right := (outer + 1) % n
	return PackedVector2Array([star_pts[left], star_pts[outer], star_pts[right]])


static func _star_polygon(
	center: Vector2, outer_r: float, inner_r: float, n: int
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(n * 2):
		var angle := (TAU / float(n * 2)) * float(i) - PI / 2.0
		var r: float = outer_r if i % 2 == 0 else inner_r
		pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	return pts
