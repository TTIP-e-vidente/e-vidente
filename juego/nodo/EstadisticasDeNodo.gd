extends RefCounted
class_name EstadisticasDeNodo

const _Reglas := preload("res://nodo/ReglasDeProgresoDeNodo.gd")

var _aciertos: int = 0
var _errores: int = 0
var _intentos: int = 0
var _inicio_ms: int = 0
var _fin_ms: int = 0


func iniciar() -> void:
	_aciertos = 0
	_errores = 0
	_intentos = 0
	_inicio_ms = Time.get_ticks_msec()
	_fin_ms = 0


func registrar_resultado(resultado: ResultadoDeMiniJuego) -> void:
	if resultado == null:
		return
	_aciertos += resultado.aciertos
	_errores += resultado.errores
	_intentos += resultado.intentos


func finalizar() -> void:
	_fin_ms = Time.get_ticks_msec()


func obtener_duracion_ms() -> int:
	if _fin_ms > 0:
		return _fin_ms - _inicio_ms
	if _inicio_ms > 0:
		return Time.get_ticks_msec() - _inicio_ms
	return 0


func obtener_precision() -> int:
	return _Reglas.calcular_precision(_aciertos, _intentos)


func obtener_porcentaje_error() -> int:
	return _Reglas.calcular_porcentaje_error(_errores, _intentos)


func a_diccionario() -> Dictionary:
	return {
		"aciertos": _aciertos,
		"errores": _errores,
		"intentos": _intentos,
		"duracion_ms": obtener_duracion_ms(),
		"precision": obtener_precision(),
		"porcentaje_error": obtener_porcentaje_error(),
	}
