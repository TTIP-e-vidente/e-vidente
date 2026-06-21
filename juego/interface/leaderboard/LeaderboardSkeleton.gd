extends VBoxContainer

# Skeleton animado para la lista del Leaderboard.
# Se encarga de hacer oscilar la opacidad de las barras (efecto "respiración").

@export var speed: float = 2.0
var _time: float = 0.0


func _ready() -> void:
	_aplicar_colores_skeleton()


func _aplicar_colores_skeleton() -> void:
	var color_base := Color(MiPaleta.VERDE_BOSQUE.r, MiPaleta.VERDE_BOSQUE.g, MiPaleta.VERDE_BOSQUE.b, 0.18)
	for fila in get_children():
		if fila is HBoxContainer:
			for hijo in fila.get_children():
				if hijo is ColorRect:
					(hijo as ColorRect).color = color_base

func _process(delta: float) -> void:
	_time += delta
	# Oscilar la modulación (transparencia) entre 0.3 y 0.7 usando el seno del tiempo
	var alpha: float = 0.5 + 0.2 * sin(_time * speed)
	modulate.a = alpha
