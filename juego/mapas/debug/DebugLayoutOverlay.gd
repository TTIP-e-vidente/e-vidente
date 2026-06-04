class_name DebugLayoutOverlay
extends Node2D

# Overlay de debug: circulo rojo + indice por posicion calculada.
# Solo se instancia cuando MapBoard.debug_layout = true.

var _posiciones: Array[Vector2] = []


func establecer_posiciones(posiciones: Array[Vector2]) -> void:
	_posiciones = posiciones
	queue_redraw()


func _draw() -> void:
	for i in _posiciones.size():
		draw_circle(_posiciones[i], 12.0, Color(1.0, 0.15, 0.15, 0.85))
		draw_string(
			ThemeDB.fallback_font,
			_posiciones[i] + Vector2(-8.0, -18.0),
			str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18,
			Color.WHITE
		)
