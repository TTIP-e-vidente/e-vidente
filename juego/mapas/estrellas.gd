extends Sprite2D

var direccion := 1
var posicion_inicial := 0.0

func _ready() -> void:
	posicion_inicial = position.x
	animacion_idle()

func animacion_idle() -> void:
	while true:
		
		# Espera random
		await get_tree().create_timer(randf_range(2.0, 3.0)).timeout
		
		# Flip horizontal
		flip_h = !flip_h
		
