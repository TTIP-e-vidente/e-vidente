# Overlay de debug para el layout automático del mapa.
# Se agrega dinámicamente como hijo de Contenido cuando debug_layout = true en MapBoard.
# Dibuja un círculo rojo y el número de cada posición calculada por MapNodePositionResolver.
# No tiene efecto visual fuera del editor / builds de debug — debug_layout está apagado por default.
extends Node2D

var dbg_positions: Array[Vector2] = []

func _draw() -> void:
	for i in dbg_positions.size():
		draw_circle(dbg_positions[i], 12.0, Color(1.0, 0.15, 0.15, 0.85))
		draw_string(
			ThemeDB.fallback_font,
			dbg_positions[i] + Vector2(-8.0, -18.0),
			str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color.WHITE
		)
