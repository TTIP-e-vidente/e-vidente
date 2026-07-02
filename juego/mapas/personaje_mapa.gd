extends Sprite2D

@export var angulo_max := 10.0
@export var velocidad := 2.0
@export var altura := 8.0

var tiempo := 0.0
var y_inicial := 0.0

func _ready() -> void:
	y_inicial = position.y

func _process(delta: float) -> void:
	tiempo += delta

	rotation_degrees = sin(tiempo * velocidad) * angulo_max
	position.y = y_inicial + cos(tiempo * velocidad) * altura
