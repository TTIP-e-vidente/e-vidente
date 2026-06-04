class_name DebugLayoutOverlay
extends Node2D

# Overlay de debug: circulo rojo + indice por posicion calculada.
# Solo se instancia cuando MapBoard.debug_layout = true.

var _posiciones: Array[Vector2] = []


func establecer_posiciones(posiciones: Array[Vector2]) -> void:
	_posiciones = posiciones
	queue_redraw()


func _draw() -> void:
	if _posiciones.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	for i in range(_posiciones.size()):
		var pos := _posiciones[i]
		draw_circle(pos, 12.0, Color(1.0, 0.15, 0.15, 0.85))
		if font == null:
			continue
		draw_string(
			font,
			pos + Vector2(-8.0, -18.0),
			str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18,
			Color.WHITE
		)
