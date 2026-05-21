extends Control


@onready var barra: ProgressBar = $"Progress-game"

var _total_objetivos: int = 1
var _completados: int = 0

func _ready() -> void:
	pass

## Configura la barra con total de juegos y cuántos están completados/activos.
func configurar(total: int, hechos: int) -> void:
	_total_objetivos = max(total, 1)
	_completados = clampi(hechos, 0, _total_objetivos)
	_actualizar_barra()

## recibe el índice del juego actual (1-based) y el total.
func actualizar_progreso(juego_actual: int, total_juegos: int) -> void:
	# N+1 estados: la barra nunca llega al 100% mientras se juega la última partida.
	configurar(total_juegos + 1, juego_actual)

## Llamar al completar el último juego del nodo.
func completar_progreso() -> void:
	configurar(1, 1)

func _actualizar_barra() -> void:
	var progreso: float = float(_completados) / float(_total_objetivos)
	var valor_objetivo: float = progreso * 100.0
	barra.value = valor_objetivo
	var tw: Tween = create_tween()
	tw.tween_property(barra, "value", valor_objetivo, 0.5)

