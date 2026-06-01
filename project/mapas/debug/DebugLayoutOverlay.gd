# Overlay de debug para el layout automático del mapa.
# Se agrega dinámicamente como hijo de Contenido cuando debug_layout = true en MapBoard.
# Dibuja un círculo rojo y el número de índice de cada posición calculada por MapNodePositionResolver.
# debug_layout = false por default → sin efecto en producción.
extends Node2D

var posiciones: Array[Vector2] = []

func _draw() -> void:
	for i in posiciones.size():
		draw_circle(posiciones[i], 12.0, Color(1.0, 0.15, 0.15, 0.85))
		draw_string(
			ThemeDB.fallback_font,
			posiciones[i] + Vector2(-8.0, -18.0),
			str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color.WHITE
		)
