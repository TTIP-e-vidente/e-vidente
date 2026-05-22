extends Control


@onready var barra: ProgressBar = $"Progress-game"

var _total_objetivos: int = 1
var _completados: int = 0

var _tween: Tween


func configurar(total: int, hechos: int) -> void:
	_total_objetivos = max(total, 1)
	_completados = clampi(hechos, 0, _total_objetivos)
	_actualizar_barra()


func actualizar_progreso(juego_actual: int, total_juegos: int) -> void:
	configurar(total_juegos + 1, juego_actual)


func completar_progreso() -> void:
	configurar(1, 1)


func _actualizar_barra() -> void:
	var progreso: float = float(_completados) / float(_total_objetivos)
	var valor_objetivo: float = progreso * 100.0

	if _tween:
		_tween.kill()

	_tween = create_tween()

	_tween.tween_property(
		barra,
		"value",
		valor_objetivo,
		0.4
	).set_trans(Tween.TRANS_CUBIC)\
	 .set_ease(Tween.EASE_OUT)
