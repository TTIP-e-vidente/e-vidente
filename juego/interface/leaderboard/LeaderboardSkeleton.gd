extends VBoxContainer

# Skeleton animado para la lista del Leaderboard.
# Se encarga de hacer oscilar la opacidad de las barras (efecto "respiración").

@export var speed: float = 2.0
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	# Oscilar la modulación (transparencia) entre 0.3 y 0.7 usando el seno del tiempo
	var alpha: float = 0.5 + 0.2 * sin(_time * speed)
	modulate.a = alpha
