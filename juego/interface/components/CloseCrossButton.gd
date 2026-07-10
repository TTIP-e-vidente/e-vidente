extends Button
class_name CloseCrossButton

# Dibuja la "cruz" de cerrar a mano en vez de depender de un glifo Unicode (✕).
# Algunas fuentes/navegadores (sobre todo en el export web para mobile) no
# incluyen ese carácter y el botón queda invisible aunque siga siendo clickeable.

@export var color_normal: Color = Color(0.278, 0.251, 0.184, 0.45)
@export var color_hover: Color = Color(0.259, 0.471, 0.369, 1.0)
@export var grosor: float = 2.4
@export var margen_relativo: float = 0.32


func _ready() -> void:
	text = ""
	flat = true
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	resized.connect(queue_redraw)


func _draw() -> void:
	var color := color_hover if is_hovered() else color_normal
	var margen_x := size.x * margen_relativo
	var margen_y := size.y * margen_relativo
	draw_line(
		Vector2(margen_x, margen_y),
		Vector2(size.x - margen_x, size.y - margen_y),
		color,
		grosor,
		true
	)
	draw_line(
		Vector2(size.x - margen_x, margen_y),
		Vector2(margen_x, size.y - margen_y),
		color,
		grosor,
		true
	)
